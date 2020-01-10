#! /usr/bin/env perl
# Planet Jupiter is a feed aggregator that creates a single HTML file
# Copyright (C) 2020  Alex Schroeder <alex@gnu.org>

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

package Jupiter;

use utf8;
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

use JSON;
use List::Util qw(uniq min);
use File::Slurp;
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

This program is used to pull together the latest updates from a bunch of other
sites and display them on a single web page. The sites we get our updates from
are defined in an OPML file.

=head2 The OPML file

You B<need> an OPML file. It's an XML file linking to I<feeds>. Here's an
example listing just one feed. In order to add more, add more C<outline>
elements with the C<xmlUrl> attribute. The exact order and nesting does not
matter. People can I<import> these OPML files into their own feed readers and
thus it may make sense to send a bit more effort in making it presentable.

    <opml version="2.0">
      <body>
        <outline title="Alex Schroeder"
                 xmlUrl="https://alexschroeder.ch/wiki?action=rss"/>
      </body>
    </opml>

=head2 Update the feeds in your cache

This is how you update the feeds in a file called C<feed.opml>. It downloads all
the feeds linked to in the OPML file and stores them in the cache directory.

    perl jupiter.pl update feed.opml

The directory used to keep a copy of all the feeds in the OPML file has the same
name as the OPML file but without the .opml extension. In other words, if your
OPML file is called C<feed.opml> then the cache directory is called C<feed>.

This operation takes long because it requests an update from all the sites
listed in your OPML file. Don't run it too often or you'll annoy the site
owners.

=head2 Generate the HTML

This is how you generate the C<index.html> file based on the feeds of your
C<feed.opml>. It assumes that you have already updated all the feeds (see
above).

    perl jupiter.pl html feed.opml

The file generation uses two templates, C<body.html> for the overall structure
and C<post.html> for each individual post. These are written for
C<Mojo::Template>. The default templates use other files, such as the logo, a
CSS file, and a small Javascript snippet to enable navigation using the C<J> and
C<K> keys.

=head2 Why separate the two steps?

The first reason is that tinkering with the templates involves running the
program again and again, and you don't want to contact all the sites whenever
you update your templates.

The other reason is that it allows you to create subsets. For example, you can
fetch the feeds for three different OPML files:

    perl jupiter.pl update osr.opml indie.opml other.opml

And then you can create three different HTML files:

    perl jupiter.pl html osr.html osr.opml
    perl jupiter.pl html indie.html indie.opml
    perl jupiter.pl html rpg.html osr.opml indie.opml other.opml

=cut

main();

sub main {
  my $command = shift @ARGV || 'help';
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
  save_feed_metadata($feeds);
  cleanup_cache($feeds);
}

sub make_promises {
  my $ua = shift;
  my $feeds = shift;
  for my $feed (@$feeds) {
    my $url = $feed->{url};
    # returning 0 in the case of an error is important
    $feed->{promise} = $ua->get_p($url)->catch(sub { $feed->{message} = "@_"; 0; });
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
      $feed->{message} = $tx->result->message;
      $feed->{code} = $tx->result->code;
      # save raw bytes
      write_file($feed->{cache_file}, $tx->result->body)
	  or warn "Unable to write $feed->{cache_file}\n";
    }
  })->catch(sub {
    warn "Something went wrong: @_";
  })->wait;
}

sub save_feed_metadata {
  my $feeds = shift;
  my %messages = map {
    $_->{url} =>
    {
      title => $_->{title},
      link => $_->{link},
      message => $_->{message},
      code => $_->{code},
    }
  } @$feeds;
  write_file('messages.json', {binmode => ':utf8'}, encode_json \%messages);
}

sub load_feed_metadata {
  my $feeds = shift;
  my $data = decode_json read_file('messages.json', {binmode => ':utf8'});
  for my $feed (@$feeds) {
    my $url = $feed->{url};
    $feed->{title} = $data->{$url}->{title} unless $feed->{title};
    $feed->{link} = $data->{$url}->{link} unless $feed->{link};
    $feed->{message} = $data->{$url}->{message} unless $feed->{message};
    $feed->{code} = $data->{$url}->{code} unless $feed->{code};
  }
}

sub cleanup_cache {
  my $feeds = shift;
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
  my (@feeds, @files);
  for my $file (@ARGV) {
    my $doc = XML::LibXML->load_xml(string => scalar read_file($file, {binmode => ':utf8'}));
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
    push @files, { file => $file, name => $name };
  }
  return \@feeds, \@files if wantarray;
  return \@feeds;
}

sub url_to_file {
  my $url = shift;
  $url =~ s/[\/?&:]+/-/g;
  return $url;
}

sub make_html {
  my ($feeds, $files) = read_opml();
  my $globals = globals($files);
  my $xpc = XML::LibXML::XPathContext->new;
  $xpc->registerNs('atom', 'http://www.w3.org/2005/Atom');
  $xpc->registerNs('html', 'http://www.w3.org/1999/xhtml');
  $xpc->registerNs('dc', 'http://purl.org/dc/elements/1.1/');
  my $entries = entries($xpc, $feeds, 4); # set messages for feeds, too
  add_data($xpc, $entries);   # extract data from the xml
  load_feed_metadata($feeds); # load messages and codes for feeds
  save_feed_metadata($feeds); # save title and link for feeds
  $entries = limit($entries, 100);
  apply_entry_template($entries, scalar read_file('post.html', {binmode => ':utf8'}));
  my $html = apply_page_template(scalar read_file('page.html', {binmode => ':utf8'}), $globals, $feeds, $entries);
  write_file('index.html', {binmode => ':utf8'}, $html);
}

sub globals {
  my $files = shift;
  my @time = gmtime;
  my $today = strftime("%Y-%m-%d", @time);
  return {date => $today, files => $files};
}

sub entries {
  my $xpc = shift;
  my $feeds = shift;
  my $limit = shift;
  my @entries;
  for my $feed (@$feeds) {
    next unless -r $feed->{cache_file};
    my $doc = eval { XML::LibXML->load_xml(string => scalar read_file($feed->{cache_file}, {binmode => ':utf8'})) };
    next unless $doc;
    # RSS and Atom! We assume that earlier entries are newer. ｢The Entries in
    # the returned Atom Feed SHOULD be ordered by their "app:edited" property,
    # with the most recently edited Entries coming first in the document order.｣
    my @nodes = $xpc->findnodes(
      "//item[position() <= $limit] | //atom:entry[position() <= $limit]",
      $doc);
    if (@nodes) {
      push(@entries, map {
	{
	  xml => $_,
	  feed => $feed,
	  blog_title => $feed->{title},
	  blog_feed => $feed->{url},
	}
      } @nodes);
      add_age_warning($xpc, $feed, $nodes[0]);
    } else {
      $feed->{message} = "Empty feed";
      $feed->{code} = 204; # no content
    }
  }
  return \@entries;
}

sub add_age_warning {
  my $xpc = shift;
  my $feed = shift;
  my $node = shift;
  my $ninety_days = 7776000; # 90 * 24 * 60 * 60
  my $seconds = parsedate $xpc->findvalue('pubDate | atom:updated', $node);
  $feed->{message} = "No updates in 90 days" if $seconds > $ninety_days;
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
    $entry->{categories} = $xpc->findnodes('category/text() | atom:category/@term', $element);
    $entry->{excerpt} = excerpt($xpc, $entry);
    $entry->{blog_link} = $xpc->findvalue('/rss/channel/link | /atom:feed/atom:link[@rel="alternate"][@type="text/html"]/@href', $element);
    $entry->{feed}->{link} = $entry->{blog_link} if $entry->{blog_link} and not $entry->{feed}->{link};
    $entry->{blog_title} = $xpc->findvalue('/rss/channel/title | /atom:feed/atom:title', $element);
    $entry->{feed}->{title} = $entry->{blog_title} if $entry->{blog_title} and not $entry->{feed}->{title};
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
  my $mnt = Mojo::Template->new;
  return $mnt->render(@_);
}
