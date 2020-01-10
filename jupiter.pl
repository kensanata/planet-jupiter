#! /usr/bin/env perl
# Copyright (C) 2020  Alex Schroeder <alex@gnu.org>

# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see <http://www.gnu.org/licenses/>.

package Jupiter;

use utf8;
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

use List::Util qw(uniq min);
use XML::LibXML;
use Modern::Perl;
use Date::Format;
use XML::Entities;
use File::Basename;
use Mojo::Template;
use Mojo::UserAgent;
use Time::ParseDate;
use Pod::Simple::Text;

=head1 Planet Jupiter

Planet Jupiter creates a static web page based on the feeds listed in an OPML
file.

You B<need> an OPML file. It's an XML file linking to I<feeds>. Here's an
example listing just one feed. In order to add more, add more C<outline>
elements with the C<xmlUrl> attribute.

    <opml version="2.0">
      <body>
	<outline title="Other Blogs">
	  <outline title="Alex Schroeder"
                   xmlUrl="https://alexschroeder.ch/wiki?action=rss"/>
	</outline>
      </body>
    </opml>

=head2 Update the feeds in your cache

This is how you update the feeds in a file called C<feed.opml>. It downloads all
the feeds linked to in the OPML file and stores them in the cache directory.

  perl jupiter.pl update feed.opml

The directory used to keep a copy of all the feeds in the OPML file has the same
name as the OPML file but without the .opml extension. In other words, if your
OPML file is called C<feed.opml> then the cache directory is called C<feed>.

=cut

main();

sub main {
  my $command = shift @ARGV;
  if ($command eq 'update') {
    update_cache();
  } elsif ($command eq 'html') {
    make_html();
  } else {
    die "Use pod2text jupiter.pl to read the documentation\n";
  }
}

sub update_cache {
  my $feeds = read_opml();
  make_directories($feeds);
  my $ua = Mojo::UserAgent->new;
  make_promises($ua, $feeds);
  fetch_feeds($feeds);
  cleanup_cache($feeds);
}

sub make_promises {
  my $ua = shift;
  my $feeds = shift;
  for my $feed (@$feeds) {
    my $url = $feed->{url};
    # returning 0 in the case of an error is important
    $feed->{promise} = $ua->get_p($url)->catch(sub{ warn "⚠ $url → @_\n"; 0; });
  }
}

sub fetch_feeds {
  my $feeds = shift;
  say "Fetching feeds...";
  Mojo::Promise->all(map { $_->{promise} } @$feeds)->then(sub {
    # all returns the values in the same order!
    for (my $i = 0; $i < @_; $i++) {
      my $feed = $feeds->[$i];
      my $value = $_[$i];
      my $tx = $value->[0];
      # relies on catch returning 0 above
      next unless $tx;
      $feed->{result} = $tx->result;
      write_file($feed->{cache_file}, $tx->result->body)
	  or warn "Unable to write $feed->{cache_file}\n";
    }
  })->catch(sub {
    warn "Something went wrong: @_";
  })->wait;
}

sub cleanup_cache {
  my $feeds = shift;
  # this is about feeds that returned an error
  my @failure = grep { not $_->{result} and -e $_->{cache_file} } @$feeds;
  if (@failure) {
    say "Removing failed requests from the cache...";
    foreach (@failure) { say "→ $_->{title}" }
    unlink map { $_->{cache_file} } @failure;
  }
  # this is about unknown files
  my %good = map { $_ => 1 } @{cache_files($feeds)};
  my @unused = grep { not $good{$_} } @{existing_files($feeds)};
  if (@unused) {
    say "Removing unused files from the cache...";
    foreach (@unused) { say "→ $_" }
    unlink @unused;
  }
}

sub existing_files {
  my $feeds = shift;
  my @files;
  for my $dir (uniq map { $_->{cache_dir} } @$feeds) {
    push(@files, <"$dir/*">);
  }
  return \@files;
}

sub cache_files {
  my $feeds = shift;
  my @files = map { $_->{cache_file} } @$feeds;
  return \@files;
}

sub make_directories {
  my $feeds = shift;
  for my $dir (uniq map { $_->{cache_dir} } @$feeds) {
    if (not -d $dir) {
      mkdir $dir;
    }
  }
}

# Creates list of feeds. Each feed is a hash with keys title, url, opml_file,
# cache_dir and cache_file.
sub read_opml {
  my @feeds;
  for my $file (@ARGV) {
    open my $fh, '<', $file or die "Cannot read $file: $!";
    binmode $fh;
    my $doc = XML::LibXML->load_xml(IO => $fh);
    my @nodes = $doc->findnodes('//outline[./@xmlUrl]');
    my $name = fileparse($file, '.opml', '.xml');
    push @feeds, map {
      my $title = $_->getAttribute('title');
      my $url = $_->getAttribute('xmlUrl');
      {
	title => $title,
	url => $url,
	opml_file => $file,
	cache_dir => $name,
	cache_file => $name . "/" . url_to_file($url),
      }
    } @nodes;
    warn "No feeds found in the OPML file $file\n" unless @nodes;
  }
  return \@feeds;
}

sub url_to_file {
  my $url = shift;
  $url =~ s/[\/?&:]+/-/g;
  return $url;
}

sub make_html {
  my $feeds = read_opml();
  my $xpc = XML::LibXML::XPathContext->new;
  $xpc->registerNs('atom', 'http://www.w3.org/2005/Atom');
  $xpc->registerNs('html', 'http://www.w3.org/1999/xhtml');
  $xpc->registerNs('dc', 'http://purl.org/dc/elements/1.1/');
  my $entries = entries($xpc, $feeds, 4);
  add_data($xpc, $entries);
  $entries = limit($entries, 100);
  local $/;
  my ($page_template, $entry_template) = split("\f", <DATA>);
  apply_entry_template($entries, $entry_template);
  my $html = apply_page_template($entries, $page_template);
  open my $fh, '>:utf8', 'index.html' or die "Cannot write index.html: $!";
  print $fh $html;
  close $fh;
}

sub entries {
  my $xpc = shift;
  my $feeds = shift;
  my $limit = shift;
  my @entries;
  for my $feed (@$feeds) {
    open my $fh, '<', $feed->{cache_file} or next;
    binmode $fh;
    my $doc = XML::LibXML->load_xml(IO => $fh);
    # RSS and Atom! We assume that earlier entries are newer. ｢The Entries in
    # the returned Atom Feed SHOULD be ordered by their "app:edited" property,
    # with the most recently edited Entries coming first in the document order.｣
    my @nodes = $xpc->findnodes(
      "//item[position() <= $limit] | //atom:entry[position() <= $limit]",
      $doc);
    push(@entries, map { { xml => $_ } } @nodes);
  }
  return \@entries;
}

sub limit {
  my $entries = shift;
  my $limit = shift;
  @$entries = sort { $b->{seconds} <=> $a->{seconds} } @$entries;
  return [@$entries[0 .. min($#$entries, $limit - 1)]];
}

sub add_data {
  my $xpc = shift;
  my $entries = shift;
  for my $entry (@$entries) {
    my $element = $entry->{xml};
    $entry->{seconds} = parsedate $xpc->findvalue('pubDate | atom:updated', $element);
    $entry->{title} = $xpc->findvalue('title | atom:title', $element);
    $entry->{link} = $xpc->findvalue('link | atom:link[@rel="alternate"][@type="text/html"]/@href', $element);
    $entry->{author} = $xpc->findvalue('dc:contributor | atom:author/atom:name', $element);
    $entry->{day} = time2str("%Y-%m-%d", $entry->{seconds}, "GMT");
    $entry->{excerpt} = excerpt($xpc, $entry);
    $entry->{blog_title} = $xpc->findvalue('/rss/channel/title | /atom:feed/atom:title', $element);
    $entry->{blog_link} = $xpc->findvalue('/rss/channel/link | /atom:feed/atom:link[@rel="alternate"][@type="text/html"]/@href', $element);
  }
}

sub excerpt {
  my $xpc = shift;
  my $entry = shift;
  my $content = $xpc->findvalue('description | atom:content', $entry->{xml});
  $content = (eval { XML::LibXML->load_xml(string => $content) }
	      || eval { XML::LibXML->load_html(string => $content) });
  return '(no excerpt)' unless $content;
  my $separator = "¶";
  for my $node ($xpc->findnodes('//p | //br | //blockquote | //li | //td | //th | //div', $content)) {
    $node->appendTextNode($separator);
  }
  $content = $content->textContent();
  $content =~ s/¶¶+/¶/g;
  $content = substr($content, 0, 500);
  $content =~ s/¶/<span class="paragraph">¶ <\/span>/g;
  return $content;
}

sub apply_entry_template {
  my $entries = shift;
  my $template = shift;
  my $mnt = Mojo::Template->new;
  for my $entry (@$entries) {
    my $html = $mnt->vars(1)->render($template, $entry);
    $entry->{html} = $html;
  }
}

sub apply_page_template {
  my $entries = shift;
  my $template = shift;
  my $mnt = Mojo::Template->new;
  return $mnt->render($template, $entries);
}

__DATA__
% my ($entries) = @_;
<!DOCTYPE html>
<html>
<head profile="http://www.w3.org/2005/10/profile">
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<link rel="shortcut icon" href="jupiter.png" type="image/png"/>
<link rel="icon" href="jupiter.png" type="image/png"/>
<link rel="stylesheet" href="default.css" type="text/css"/>
<title>RPG Planet</title>
<meta name="robots" content="noindex,nofollow">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="generator" content="Venus">
<link rel="alternate" href="https://campaignwiki.org/rpg/atom.xml" title="RPG Planet" type="application/atom+xml">
<script type="text/javascript" src="personalize.js"> </script></head>

<body>
  <p class="invisible">
    <a href="#body">Skip to content</a>
  <h1>RPG Planet</h1>
  <div id="sidebar">
    <p class="logo">
      <img src="jupiter.svg">
    <p class="small">
      <a href="/wiki/Planet/What_is_this%3f">What is this?</a> •
      <a href="/wiki/Planet/Please_join!">Please join!</a>
    <h2><label for="toggle">Members</label></h2>
    <input type="checkbox" id="toggle">
    <ul id="toggled">
      <li>...</li>
    </ul>
    <h2>Info</h2>
    <dl>
      <dt>Last updated:</dt>
      <dd><span class="date" title="GMT">2020-01-09</span></dd>
      <dt>Powered by:</dt>
      <dd><a href="https://alexschroeder.ch/cgit/planet-jupiter/about/" class="jupiter button">Jupiter</a></dd>
      <dt>Export:</dt>
      <dd><a href="opml.xml" class="opml button">OPML</a></dd>
      <dd><a href="atom.xml" class="atom button">Atom</a></dd>
    </dl>
  </div>
  <div id="body">
% my $day = "";
% for my $entry (@$entries) {
% if ($entry->{day} ne $day) {
%   $day = $entry->{day};
    <h2 class="date"><%= $entry->{day} =%></h2>
% }
%= $entry->{html}
% }
    </div>
  </body>
</html>

<div class="post">
  <h3>
    <a href="<%= $blog_link %>"><%= $blog_title %></a> — <a href="<%= $link %>"><%= $title %></a>
  </h3>
  <div class="content">
    <%= $excerpt %>
  </div>
  <div class="permalink">
    <a href="<%= $link %>" class="permalink">
    by <%= $author %> at <span class="date" title="GMT"><%= $day %></span></a>
  </div>
</div>
