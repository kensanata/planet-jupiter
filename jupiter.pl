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

The OPML file must use the .opml extension. You can update the feeds for
multiple OPML files in one go.

=head2 Generate the HTML

This is how you generate the C<index.html> file based on the feeds of your
C<feed.opml>. It assumes that you have already updated all the feeds (see
above).

    perl jupiter.pl html feed.opml

The file generation uses a template, C<template.html>. It is written for
C<Mojo::Template>. The default templates use other files, such as the logo, the
feed icon, a CSS file, and a small Javascript snippet to enable navigation using
the C<J> and C<K> keys.

You can specify a different HTML file to generate:

    perl jupiter.pl html your.html feed.opml

If you specify two HTML files, the first is the HTML file to generate and the
second is the template to use:

    perl jupiter.pl html your.html your-template.html feed.opml

=head2 Generate the RSS feed

This happens at the same time as when you generate the HTML. It takes all the
entries that are being added to the HTML and puts the into a feed. If you don't
specify an HTML file, it tries to use C<feed.rss> as the template for the feed
and it writes all the entries into a file called C<feed.xml>. Again, the
template is written for C<Mojo::Template>.

You can specify up to two XML, RSS or ATOM files. The first is the name of the
feed to generate, the second is the template to use:

    perl jupiter.pl html atom.xml template.xml planet.html template.html feed.opml

For more information about feeds, take a look at the specifications:

=over

=item RSS 2.0, L<https://cyber.harvard.edu/rss/rss.html>

=item Atom Syndication, L<https://tools.ietf.org/html/rfc4287>

=back

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

For an example of how it might look, check out the setup for the planets I run.
L<https://alexschroeder.ch/cgit/planet/about/>

=head2 What about the JSON file?

There's a JSON file that gets generated and updated as you run Planet Jupiter.
It's name depends on the OPML files used. It records metadata for every feed in
the OPML file that isn't stored in the feeds themselves.

=over

=item C<message> is the HTTP status message, or a similar message such as "No
entry newer than 90 days." This is set when update the feeds in your cache.

=item C<message> is the HTTP status code; this code could be the real status
code from the server (such as 404 for a "not found" status) or one generated by
Jupiter such that it matches the status message (such as 206 for a "partial
content" status when there aren't any recent entries in the feed). This is set
when update the feeds in your cache.

=item C<title> is the site's title. When you update the feeds in your cache, it
is taken from the OPML file. That's how the feed can have a title even if the
download failed. When you generate the HTML, the feeds in the cache are parsed
and if a title is provided, it is stored in the JSON file and overrides the
title in the OPML file.

=item C<link> is the site's link for humans. When you generate the HTML, the
feeds in the cache are parsed and if a title is provided, it is stored in the
JSON file and overrides the link in the OPML file.

=item C<last_modified> and C<etag> are two headers used for caching
from the HTTP response that cannot be changed by data in the feed.

=back

If we run into problems downloading a feed, this setup allows us to still link
to the feeds that aren't working, using their correct names, and describing the
error we encountered.

=head2 Logging

Use the C<--log=LEVEL> to set the log level. Valid values for LEVEL are debug,
info, warn, error, and fatal.

=head2 Dependencies

To run Jupiter on Debian:

=over

=item C<libmodern-perl-perl> for L<Modern::Perl>

=item  C<libmojolicious-perl> for L<Mojo::Template> and L<Mojo::UserAgent>

=item C<libxml-libxml-perl> for L<XML::LibXML>

=item C<libfile-slurper-perl> for L<File::Slurper>

=item C<libcpanel-json-xs-perl> for L<Cpanel::JSON::XS>

=item C<libdatetime-perl> for L<DateTime>

=item C<libdatetime-format-mail-perl> for L<DateTime::Format::Mail>

=item C<libdatetime-format-iso8601-perl> for L<DateTime::Format::ISO8601>

=back

Unfortunately, L<Mojo::UserAgent::Role::Queued> isn't packaged for Debian.
Therefore, let's build it and install it as a Debian package.

    sudo apt-get install libmodule-build-tiny-perl
    sudo apt-get install dh-make-perl
    sudo dh-make-perl --build --cpan Mojo::UserAgent::Role::Queued
    dpkg --install libmojo-useragent-role-queued-perl_1.15-1_all.deb

To generate the C<README.md> from the source file: C<libpod-markdown-perl>.

=cut

use Cpanel::JSON::XS;
use DateTime;
use DateTime::Format::Mail;
use DateTime::Format::ISO8601;
use File::Basename;
use File::Slurper qw(read_binary write_binary read_text write_text);
use List::Util qw(uniq min shuffle);
use Modern::Perl;
use Mojo::Log;
use Mojo::Template;
use Mojo::UserAgent;
use Pod::Simple::Text;
use XML::LibXML;
use Mojo::Util qw(slugify trim xml_escape html_unescape);

use vars qw($log);
our $log = Mojo::Log->new;

my $xpc = XML::LibXML::XPathContext->new;
$xpc->registerNs('atom', 'http://www.w3.org/2005/Atom');
$xpc->registerNs('html', 'http://www.w3.org/1999/xhtml');
$xpc->registerNs('dc', 'http://purl.org/dc/elements/1.1/');

my $undefined_date = DateTime->from_epoch( epoch => 0 );

# Our tests don't want to call main
__PACKAGE__->main unless caller;

sub main {
  my ($log_level) = grep /^--log=/, @ARGV;
  $log->level(substr($log_level, 6)) if $log_level;
  my ($command) = grep /^[a-z]+$/, @ARGV;
  $command ||= 'help';
  if ($command eq 'update') {
    update_cache(@ARGV);
  } elsif ($command eq 'html') {
    make_html(@ARGV);
  } else {
    die "Use pod2text jupiter.pl to read the documentation\n";
  }
}

sub update_cache {
  my ($feeds, $files) = read_opml(@_);
  make_directories($feeds);
  load_feed_metadata($feeds, $files);
  my $ua = Mojo::UserAgent->new->with_roles('+Queued')
      ->max_redirects(3)
      ->max_active(5);
  make_promises($ua, $feeds);
  fetch_feeds($feeds);
  save_feed_metadata($feeds, $files);
  cleanup_cache($feeds);
}

sub make_promises {
  my $ua = shift;
  my $feeds = shift;
  for my $feed (@$feeds) {
    my $url = html_unescape $feed->{url}; # undo xml_escape for the request
    $ua->on(start => sub {
      my ($ua, $tx) = @_;
      $tx->req->headers->if_none_match($feed->{etag}) if ($feed->{etag});
      $tx->req->headers->if_modified_since($feed->{last_modified}) if ($feed->{last_modified});
    });
    $feed->{promise} = $ua->get_p($url)
	->catch(sub {
	  $feed->{message} = "@_";
	  $feed->{code} = 521;
	  # returning 0 in the case of an error is important
	  0; })
	# sleeping to stop blogger.com from blocking us
	->finally(sub { $log->debug($url); sleep 2; });
  }
}

sub fetch_feeds {
  my $feeds = shift;
  $log->info("Fetching feeds...");
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
      $feed->{last_modified} = $tx->result->headers->last_modified;
      $feed->{etag} = $tx->result->headers->etag;
      # save raw bytes if this is a success
      eval { write_binary($feed->{cache_file}, $tx->result->body) } if $tx->result->is_success;
      warn "Unable to write $feed->{cache_file}: $@\n" if $@;
    }
  })->catch(sub {
    warn "Something went wrong: @_";
  })->wait;
}

sub load_feed_metadata {
  my $feeds = shift;
  my $files = shift;
  for my $file (@$files) {
    my $filename = "$file->{path}/$file->{name}";
    next unless -r "$filename.json";
    my $data = decode_json read_binary("$filename.json");
    for my $feed (@$feeds) {
      my $url = $feed->{url};
      # don't overwrite title from OPML file
      $feed->{title} = $data->{$url}->{title} if $data->{$url}->{title};
      # all the other metadata is loaded from the JSON file
      $feed->{link} = $data->{$url}->{link};
      $feed->{message} = $data->{$url}->{message};
      $feed->{code} = $data->{$url}->{code};
      $feed->{last_modified} = $data->{$url}->{last_modified};
      $feed->{etag} = $data->{$url}->{etag};
    } grep { $_->{opml_file} eq $file->{file} } @$feeds;
  }
}

sub save_feed_metadata {
  my $feeds = shift;
  my $files = shift;
  for my $file (@$files) {
    my $name = $file->{name};
    my %messages = map {
      my $feed = $_;
      $feed->{url} => { map { $_ => $feed->{$_} } grep { $feed->{$_} } qw(title link message code last_modified etag) };
    } grep { $_->{opml_file} eq $file->{file} } @$feeds;
    write_binary("$file->{path}/$file->{name}.json", encode_json \%messages);
  }
}

sub cleanup_cache {
  my $feeds = shift;
  my %good = map { $_ => 1 } @{cache_files($feeds)};
  my @unused = grep { not $good{$_} } @{existing_files($feeds)};
  if (@unused) {
    $log->info("Removing unused files from the cache...");
    foreach (@unused) { $log->info($_) }
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

sub make_html {
  my ($feeds, $files) = read_opml(@_);
  load_feed_metadata($feeds, $files); # load messages and codes for feeds
  my $globals = globals($files);
  my $entries = entries($feeds, 4); # set data for feeds, too
  add_data($feeds, $entries);   # extract data from the xml
  save_feed_metadata($feeds, $files); # save title and link for feeds
  $entries = limit($entries, 100);
  write_text(html_file(@_), apply_template(read_text(html_template_file(@_)), $globals, $feeds, $entries));
  write_text(feed_file(@_), apply_template(read_text(feed_template_file(@_)), $globals, $feeds, $entries));
}

sub html_file {
  my ($html) = grep /\.html$/, @_;
  return $html||'index.html';
}

sub html_template_file {
  my ($html, $template) = grep /\.html$/, @_;
  $template ||= 'template.html';
  die "HTML template $template not found\n" unless -r $template;
  return $template;
}

sub feed_file {
  my ($feed) = grep /\.(xml|rss|atom)$/, @_;
  return $feed if $feed;
  return 'feed.xml';
}

sub feed_template_file {
  my ($feed, $template) = grep /\.(xml|rss|atom)$/, @_;
  return $template if $template;
  return 'feed.rss';
}

sub apply_template {
  my $mnt = Mojo::Template->new;
  return $mnt->render(@_);
}

=head2 Writing templates

The page template is called with three hash references: C<globals>, C<feeds>,
and C<entries>. The keys of these three hash references are documented below.
The values of these hashes are all I<escaped HTML> except where noted (dates and
file names, for example).

The technical details of how to write the templates are documented in the man
page for L<Mojo::Template>.

=head3 Globals

There are not many global keys.

B<date> is the the publication date of the HTML page, in ISO date format:
YYYY-MM-DD.

B<files> is the list of OPML files used.

=cut

sub globals {
  my $files = shift;
  my @time = gmtime;
  my $today = DateTime->now->ymd;
  return {date => $today, files => $files};
}

=head3 Writing templates for feeds

Feeds have the following keys available:

B<title> is the title of the feed.

B<url> is the URL of the feed (RSS or Atom). This is not the link to the site!

B<link> is the URL of the web page (HTML). This is the link to the site.

B<opml_file> is the file name where this feed is listed.

B<cache_dir> is the directory where this feed is cached.

B<message> is the HTTP status message or other warning or error that we got
while fetching the feed.

B<code> is the HTTP status code we got while fetching the feed.

B<doc> is the L<XML::LibXML::Document>. Could be either Atom or RSS!

=cut

# Creates list of feeds. Each feed is a hash with keys title, url, opml_file,
# cache_dir and cache_file.
sub read_opml {
  my (@feeds, @files);
  for my $file (grep /\.opml/, @_) {
    my $doc = XML::LibXML->load_xml(location => $file); # this better have no errors!
    my @nodes = $doc->findnodes('//outline[./@xmlUrl]');
    my ($name, $path) = fileparse($file, '.opml', '.xml');
    push @feeds, map {
      my $title = xml_escape $_->getAttribute('title');
      my $url = xml_escape $_->getAttribute('xmlUrl');
      {
	title => $title,    # title in the OPML file
	url => $url,        # feed URL in the OPML file
	opml_file => $file,
	cache_dir => "$path/$name",
	cache_file => "$path/$name/" . slugify($url),
      }
    } @nodes;
    warn "No feeds found in the OPML file $file\n" unless @nodes;
    push @files, { file => $file, path => $path, name => $name };
  }
  @feeds = shuffle @feeds;
  return \@feeds, \@files;
}

sub entries {
  my $feeds = shift;
  my $limit = shift;
  my $date = DateTime->now(time_zone => 'UTC')->subtract( days => 90 ); # compute once
  my @entries;
  for my $feed (@$feeds) {
    next unless -r $feed->{cache_file};
    my $doc = eval { XML::LibXML->load_xml(recover => 2, location => $feed->{cache_file} )};
    if (not $doc) {
      $feed->{message} = xml_escape "Parsing error: $@";
      $feed->{code} = 422; # unprocessable
      next;
    }
    $feed->{doc} = $doc;
    my @nodes = $xpc->findnodes("/rss/channel/item | /atom:feed/atom:entry", $doc);
    if (not @nodes) {
      $feed->{message} = "Empty feed";
      $feed->{code} = 204; # no content
      next;
    }
    # if this is an Atom feed, we need to sort the entries ourselves (older entries at the end)
    my @candidates = map {
      my $entry = {};
      $entry->{element} = $_;
      $entry->{id} = id($_);
      $entry->{date} = updated($_) || $undefined_date;
      $entry;
    } @nodes;
    @candidates = unique(sort { DateTime->compare( $b->{date}, $a->{date} ) } @candidates);
    @candidates = @candidates[0 .. min($#candidates, $limit - 1)];
    # now that we have limited the candidates, let's add more metadata from the feed
    for my $entry (@candidates) {
      $entry->{feed} = $feed;
      # these two are already escaped
      $entry->{blog_title} = $feed->{title};
      $entry->{blog_url} = $feed->{url};
    }
    add_age_warning($feed, \@candidates, $date);
    push @entries, @candidates;
  }
  return \@entries;
}

sub add_age_warning {
  my $feed = shift;
  my $entries = shift;
  my $date = shift;
  # feed modification date is smaller than the date given
  my ($node) = $xpc->findnodes("/rss/channel | /atom:feed", $feed->{doc});
  my $feed_date = updated($node);
  if ($feed_date and DateTime->compare($feed_date, $date) == -1) {
    $feed->{message} = "No feed updates in 90 days";
    $feed->{code} = 206; # partial content
    return;
  } else {
    # or no entry found with a modification date equal or bigger than the date given
    for my $entry (@$entries) {
      return if DateTime->compare($entry->{date}, $date) >= 0;
    }
    $feed->{message} = "No entry newer than 90 days";
    $feed->{code} = 206; # partial content
  }
}

sub updated {
  my $node = shift;
  return unless $node;
  my @nodes = $xpc->findnodes('pubDate | atom:updated', $node) or return;
  my $date = $nodes[0]->textContent;
  my $dt = eval { DateTime::Format::Mail->parse_datetime($date) }
  || eval { DateTime::Format::ISO8601->parse_datetime($date) };
  return $dt;
}

sub id {
  my $node = shift;
  return unless $node;
  my $id = $xpc->findvalue('guid | atom:id', $node); # id is mandatory for Atom
  $id ||= $node->findvalue('link'); # one of the following three is mandatory for RSS
  $id ||= $node->findvalue('title');
  $id ||= $node->findvalue('description');
  return $id;
}

sub unique {
  my %seen;
  my @unique;
  for my $node (@_) {
    next if $seen{$node->{id}};
    $seen{$node->{id}} = 1;
    push(@unique, $node);
  }
  return @unique;
}

sub limit {
  my $entries = shift;
  my $limit = shift;
  # we want the most recent entries overall
  @$entries = sort { DateTime->compare( $b->{date}, $a->{date} ) } unique(@$entries);
  return [@$entries[0 .. min($#$entries, $limit - 1)]];
}

=head3 Writing templates for entries

Entries have the following keys available:

B<title> is the title of the post.

B<link> is the URL to the post on the web (probably a HTML page).

B<blog_title> is the title of the site.

B<blog_link> is the URL for the site on the web (probably a HTML page).

B<blog_url> is the URL for the site's feed (RSS or Atom).

B<authors> are the authors (or the Dublin Core contributor), a list of strings.

B<date> is the publication date, as a DateTime object.

B<day> is the publication date, in ISO date format: YYYY-MM-DD, for the UTC
timezone. The UTC timezone is picked so that the day doesn't jump back and forth
when sorting entries by date.

B<content> is the full post content, as string or encoded HTML.

B<excerpt> is the post content, limited to 500 characters, with paragraph
separators instead of HTML elements, as HTML. It is not encoded because the idea
is that it only gets added to the HTML and not to the feed, and the HTML it
contains is very controlled (only the pilcrow sign inside a span to indicate
paragraph breaks).

B<categories> are the categories, a list of strings.

B<element> is for internal use only. It contains the L<XML::LibXML::Element>
object. This could be RSS or Atom!

B<feed> is for internal use only. It's a reference to the feed this entry
belongs to.

=cut

sub add_data {
  my $feeds = shift;
  my $entries = shift;
  # A note on the use of xml_escape: whenever we get data from the feed itself,
  # it needs to be escaped if it gets printed into the HTML. For example: the
  # feed contains a feed title of "Foo &amp; Bar". findvalue returns "Foo &
  # Bar". When the template inserts the title, however, we want "Foo &amp; Bar",
  # not "Foo & Bar". Thus: any text we get from the feed needs to be escaped
  # if there's a chance we're going to print it again.
  for my $feed (@$feeds) {
    next unless $feed->{doc};
    # data in the feed overrides defaults set in the OPML (XML already escaped)
    $feed->{title} = xml_escape $xpc->findvalue('/rss/channel/title | /atom:feed/atom:title', $feed->{doc}) || $feed->{title} || "";
    $feed->{url} = xml_escape $xpc->findvalue('/atom:feed/atom:link[@rel="self"]/@href', $feed->{doc}) || $feed->{url} || "";
    $feed->{link} = xml_escape $xpc->findvalue('/rss/channel/link | /atom:feed/atom:link[@rel="alternate"][@type="text/html"]/@href', $feed->{doc}) || $feed->{link} || "";
  }
  for my $entry (@$entries) {
    # copy from the feed (XML is already escaped)
    $entry->{blog_link} = $entry->{feed}->{link};
    $entry->{blog_title} = $entry->{feed}->{title};
    $entry->{blog_url} = $entry->{feed}->{url};
    # parse the elements
    my $element = $entry->{element};
    $entry->{title} = xml_escape $xpc->findvalue('title | atom:title', $element) || "Untitled";
    $entry->{link} = xml_escape $xpc->findvalue('link | atom:link[@rel="alternate"][@type="text/html"]/@href', $element);
    $entry->{link} ||= xml_escape $xpc->findvalue('atom:link/@href', $element) || "";
    my @authors = map { xml_escape strip_html($_->to_literal) } $xpc->findnodes(
      'author | atom:author/atom:name | atom:contributor/atom:name | dc:creator | dc:contributor', $element);
    @authors = map { xml_escape strip_html($_->to_literal) } $xpc->findnodes(
      '/atom:feed/atom:author/atom:name | '
      . '/atom:feed/atom:contributor/atom:name | '
      . '/rss/channel/dc:creator | '
      . '/rss/channel/dc:contributor | '
      . '/rss/channel/webMaster ', $element) unless @authors;
    $entry->{authors} = @authors ? \@authors : undef; # key must exist in the hash
    if (DateTime->compare($entry->{date}, $undefined_date) == 0) {
      $entry->{day} =  "(no date found)";
    } else {
      $entry->{day} = $entry->{date}->clone->set_time_zone('UTC')->ymd; # operate on a clone
    }
    my @categories = map { xml_escape strip_html($_->to_literal) } $xpc->findnodes('category | atom:category/@term', $element);
    $entry->{categories} = @categories ? \@categories : undef; # key must exist in the hash
    my $content = $xpc->findvalue('description | atom:content | summary | atom:summary', $element);
    $entry->{content} = xml_escape $content;
    $entry->{excerpt} = excerpt($content);
  }
}

sub excerpt {
  my $content = shift;
  return '(no excerpt)' unless $content;
  my $doc = eval { XML::LibXML->load_html(recover => 2, string => $content) };
  my $separator = "¶";
  for my $node ($doc->findnodes('//style')) {
    $node->parentNode->removeChild($node);
  }
  for my $node ($doc->findnodes('//p | //br | //blockquote | //li | //td | //th | //div')) {
    $node->appendTextNode($separator);
  }
  my $text = strip_html($doc->textContent()); # hack: fix double escaping!
  $text =~ s/( +|----+)/ /g;
  # collapse whitespace and trim
  $text =~ s/\s+/ /g;
  $text = trim $text;
  # replace paragraph repeats with their surrounding spaces
  $text =~ s/ ?¶( ?¶)* ?/¶/g;
  $text =~ s/^¶//;
  $text =~ s/¶$//;
  my $len = length($text);
  $text = substr($text, 0, 500);
  $text .= "…" if $len > 500;
  $text = xml_escape $text;
  $text =~ s/¶/<span class="paragraph">¶ <\/span>/g;
  return $text;
}

# When there's a value that's supposed to be text but isn't, then we can try to
# turn it to HTML and from there to text... This is an ugly hack and I wish it
# wasn't necessary.
sub strip_html {
  my $str = shift;
  return '' unless $str;
  my $doc = eval { XML::LibXML->load_html(string => $str) };
  return $str unless $doc;
  return $doc->textContent();
}

1;
