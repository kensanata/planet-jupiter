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

=head2 Generate the HTML

This is how you generate the C<index.html> file based on the feeds of your
C<feed.opml>. It assumes that you have already updated all the feeds (see
above).

    perl jupiter.pl html feed.opml

The file generation uses two templates, C<page.html> for the overall structure
and C<post.html> for each individual post. These are written for
C<Mojo::Template>. The default templates use other files, such as the logo, a
CSS file, and a small Javascript snippet to enable navigation using the C<J> and
C<K> keys.

You can specify a different HTML file to generate:

    perl jupiter.pl html your.html feed.opml

In this case, the two templates used have names that are based on the name of
your HTML file: C<your-page.html> for the overall structure and
C<your-post.html> for each individual post.

=head2 Generate the RSS feed

This happens at the same time as when you generate the HTML. It takes all the
entries that are being added to the HTML and puts the into a feed. If you don't
specify an HTML file, it tries to use C<feed.rss> as the template for the feed
and it writes all the entries into a file called C<feed.xml>.

If you specify a different HTML file to generate, the RSS feed uses the same
base name.

    perl jupiter.pl html your.html feed.opml

In this case, the RSS template is C<your.rss> and the RSS feed is C<your.xml>.

The RSS template should probably be really simple and just contain a C<title>
and a C<link> element. Something like the following will do:

    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0">
    <channel>
    <title>Old School RPG Planet</title>
    <link>https://campaignwiki.org/osr</link>
    </channel>
    </rss>

For more information, take a look at the RSS 2.0 specification.
L<https://cyber.harvard.edu/rss/rss.html>

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
    dpkg --install libmojo-useragent-role-queued-perl_1.15-1_all.de

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

use vars qw($log);
our $log = Mojo::Log->new;

my $xpc = XML::LibXML::XPathContext->new;
$xpc->registerNs('atom', 'http://www.w3.org/2005/Atom');
$xpc->registerNs('html', 'http://www.w3.org/1999/xhtml');
$xpc->registerNs('dc', 'http://purl.org/dc/elements/1.1/');

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
    my $url = $feed->{url};
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
      # save raw bytes
      eval { write_binary($feed->{cache_file}, $tx->result->body) };
      warn "Unable to write $feed->{cache_file}: $@\n" if $@;
    }
  })->catch(sub {
    warn "Something went wrong: @_";
  })->wait;
}

sub save_feed_metadata {
  my $feeds = shift;
  my $files = shift;
  for my $file (@$files) {
    my $name = $file->{name};
    my %messages = map {
      $_->{url} =>
      {
	title => $_->{title},
	link => $_->{link},
	message => $_->{message},
	code => $_->{code},
      }
    } grep { $_->{opml_file} eq $file->{file} } @$feeds;
    write_binary("$file->{path}/$file->{name}.json", encode_json \%messages);
  }
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
      $feed->{title} = $data->{$url}->{title} unless $feed->{title};
      $feed->{link} = $data->{$url}->{link} unless $feed->{link};
      $feed->{message} = $data->{$url}->{message} unless $feed->{message};
      $feed->{code} = $data->{$url}->{code} unless $feed->{code};
    } grep { $_->{opml_file} eq $file->{file} } @$feeds;
  }
}

sub cleanup_cache {
  my $feeds = shift;
  my %good = map { $_ => 1 } @{cache_files($feeds)};
  my @unused = grep { not $good{$_} } @{existing_files($feeds)};
  if (@unused) {
    $log->info("Removing unused files from the cache...");
    foreach (@unused) { $log->info("→ $_") }
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

sub url_to_file {
  my $url = shift;
  $url =~ s/[\/?&:]+/-/g;
  return $url;
}

sub make_html {
  my ($feeds, $files) = read_opml(@_);
  my $globals = globals($files);
  my $entries = entries($feeds, 4); # set data for feeds, too
  add_data($feeds, $entries);   # extract data from the xml
  load_feed_metadata($feeds, $files); # load messages and codes for feeds
  save_feed_metadata($feeds, $files); # save title and link for feeds
  $entries = limit($entries, 100);
  my ($page_template, $entry_template) = template_files(@_);
  apply_entry_template(read_text($entry_template), $entries);
  my $html = apply_page_template(read_text($page_template), $globals, $feeds, $entries);
  write_text(html_file(@_), $html);
  write_binary(rss_file(@_), merged_feed(rss_template_file(@_), $entries));
}

sub html_file {
  my ($html) = grep /\.html$/, @_;
  return $html||'index.html';
}

sub rss_file {
  my ($html) = grep /\.html$/, @_;
  return 'feed.xml' unless $html;
  return substr($html, 0, -4) . "xml";
}

sub rss_template_file {
  my ($html) = grep /\.html$/, @_;
  return 'feed.rss' unless $html;
  return substr($html, 0, -4) . "rss";
}

sub template_files {
  my ($html) = grep /\.html$/, @_;
  return ('page.html', 'post.html') unless $html;
  my $base = substr($html, 0, -5);
  my ($page_template, $entry_template) = ("$base-page.html", "$base-post.html");
  die "Page template $page_template not found\n" unless -r $page_template;
  die "Entry template $entry_template not found\n" unless -r $entry_template;
  return ($page_template, $entry_template);
}

=head2 Writing templates

The page template is called with three hash references: C<globals>, C<feeds>,
and C<entries>. The keys of these three hash references are documented below.

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
  for my $file (grep /\.(opml|xml)/, @_) {
    my $doc = XML::LibXML->load_xml(location => $file); # this better have no errors!
    my @nodes = $doc->findnodes('//outline[./@xmlUrl]');
    my ($name, $path) = fileparse($file, '.opml', '.xml');
    push @feeds, map {
      my $title = $_->getAttribute('title');
      my $url = $_->getAttribute('xmlUrl');
      {
	title => $title,    # title in the OPML file
	url => $url,        # feed URL in the OPML file
	opml_file => $file,
	cache_dir => "$path/$name",
	cache_file => "$path/$name/" . url_to_file($url),
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
  my $date = DateTime->now->subtract( days => 90 ); # compute once
  my @entries;
  for my $feed (@$feeds) {
    next unless -r $feed->{cache_file};
    my $doc = eval { XML::LibXML->load_xml(recover => 2, location => $feed->{cache_file} )};
    if (not $doc) {
      $feed->{message} = "Parsing error: $@";
      $feed->{code} = 422; # unprocessable
      next;
    }
    $feed->{doc} = $doc;
    my @nodes = $xpc->findnodes("/rss/channel/item[position() <= $limit] "
				. " | /atom:feed/atom:entry[position() <= $limit]", $doc);
    if (not @nodes) {
      $feed->{message} = "Empty feed";
      $feed->{code} = 204; # no content
      next;
    }
    add_age_warning($feed, \@nodes, $date);
    push @entries, map {
      {
	element => $_,
	feed => $feed,
	blog_title => $feed->{title},
	blog_url => $feed->{url},
      }
    } @nodes;
  }
  return \@entries;
}

sub add_age_warning {
  my $feed = shift;
  my $nodes = shift;
  my $date = shift;
  # feed modification date is smaller than the date given
  my ($node) = $xpc->findnodes("/rss/channel | /atom:feed", $feed->{doc});
  my $feed_date = updated($node);
  if ($feed_date) {
    if (DateTime->compare_ignore_floating($feed_date, $date) == -1) {
      $feed->{message} = "No feed updates in 90 days";
      $feed->{code} = 206; # partial content
      return;
    }
  } else {
    # or no entry found with a modification date equal or bigger than the date given
    for my $node (@$nodes) {
      my $node_date = updated($node);
      return if $node_date and DateTime->compare_ignore_floating($node_date, $date) >= 0;
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

sub limit {
  my $entries = shift;
  my $limit = shift;
  @$entries = sort { $b->{day} cmp $a->{day} } @$entries;
  return [@$entries[0 .. min($#$entries, $limit - 1)]];
}

=head3 Writing templates for entries

Entries have the following keys available:

B<title> is the title of the post.

B<link> is the URL to the post on the web (probably a HTML page).

B<blog_title> is the title of the site.

B<blog_link> is the URL for the site on the web (probably a HTML page).

B<blog_url> is the URL for the site's feed (RSS or Atom).

B<author> is the author (or the Dublin Core contributor).

B<date> is the publication date, as a DateTime object.

B<day> is the publication date, in ISO date format: YYYY-MM-DD.

B<content> is the full post content, as string or encoded HTML.

B<excerpt> is the post content, limited to 500 characters, with paragraph
separators instead of HTML elements, as HTML.

B<categories> are the categories, a list of strings.

B<element> is for internal use only. It contains the L<XML::LibXML::Element>
object. This could be RSS or Atom!

B<feed> is for internal use only. It's a reference to the feed this entry
belongs to.

=cut

sub add_data {
  my $feeds = shift;
  my $entries = shift;
  for my $feed (@$feeds) {
    next unless $feed->{doc};
    # data in the feed overrides defaults set in the OPML
    $feed->{title} = $xpc->findvalue('/rss/channel/title | /atom:feed/atom:title', $feed->{doc}) || $feed->{title} || "";
    $feed->{url} = $xpc->findvalue('/atom:feed/atom:link[@rel="self"]/@href', $feed->{doc}) || $feed->{url} || "";
    $feed->{link} = $xpc->findvalue('/rss/channel/link | /atom:feed/atom:link[@rel="alternate"][@type="text/html"]/@href', $feed->{doc}) || $feed->{link} || "";
  }
  for my $entry (@$entries) {
    # copy from the feed
    $entry->{blog_link} = $entry->{feed}->{link};
    $entry->{blog_title} = $entry->{feed}->{title};
    $entry->{blog_url} = $entry->{feed}->{url};
    # parse the elements
    my $element = $entry->{element};
    $entry->{title} = $xpc->findvalue('title | atom:title', $element) || "Untitled";
    $entry->{link} = $xpc->findvalue('link | atom:link[@rel="alternate"][@type="text/html"]/@href', $element) || "";
    $entry->{author} = $xpc->findvalue(
      'author | atom:author/atom:name | dc:creator | dc:contributor '
      . ' | /webMaster | /atom:author/atom:name | /dc:creator | /dc:contributor', $element);
    my $date = updated($element);
    $entry->{date} = $date;
    $entry->{day} = $date ? $date->ymd : "(no date found)";
    my @categories = map { $_->to_literal } $xpc->findnodes('category | atom:category/@term', $element);
    $entry->{categories} = @categories ? \@categories : undef;
    $entry->{content} = $xpc->findvalue('description | atom:content | summary | atom:summary', $element);
    $entry->{excerpt} = excerpt($entry->{content});
  }
}

sub excerpt {
  my $content = shift;
  return '(no excerpt)' unless $content;
  my $doc = eval { XML::LibXML->load_html(recover => 2, string => $content) };
  if (not $doc->documentElement()) {
    # plain text
    my $len = length($content);
    $content = substr($content, 0, 500);
    $content .= "…" if $len > 500;
    return $content;
  }
  my $separator = "¶";
  for my $node ($doc->findnodes('//p | //br | //blockquote | //li | //td | //th | //div')) {
    $node->appendTextNode($separator);
  }
  my $text = $doc->textContent();
  $text =~ s/( +|----+)/ /g;
  $text =~ s/\s*¶(\s*¶)+\s*/¶/g;
  $text =~ s/^¶//g;
  $text =~ s/¶$//g;
  my $len = length($text);
  $text = substr($text, 0, 500);
  $text .= "…" if $len > 500;
  $text =~ s/¶/<span class="paragraph">¶ <\/span>/g;
  return $text;
}

sub apply_entry_template {
  my $template = shift;
  my $entries = shift;
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

sub merged_feed {
  my $template = shift;
  my $entries = shift;
  my $doc;
  if (-f $template) {
    $doc = XML::LibXML->load_xml(location => $template);
  } else {
    $doc = XML::LibXML->load_xml(string => <<'EOT');
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
<channel>
<title>Planet</title>
<link>https://alexschroeder.ch/cgit/planet-jupiter/about</link>
</channel>
</rss>
EOT
  }
  my ($channel) = $doc->findnodes('/rss/channel');
  my $pubDate = DateTime::Format::Mail->format_datetime(DateTime->now);
  $channel->appendTextChild('pubDate', $pubDate);
  $channel->appendTextNode("\n");
  for my $entry (@$entries) {
    my $item = XML::LibXML::Element->new('item');
    $item->appendTextChild('title', $entry->{title});
    $item->appendTextChild('link', $entry->{link});
    if ($entry->{date}) {
      $pubDate = DateTime::Format::Mail->format_datetime($entry->{date});
      $item->appendTextChild('pubDate', $pubDate);
    }
    for my $category (@{$entry->{categories}}) {
      $item->appendTextChild('category', $category);
    }
    $item->appendTextChild('description', $entry->{content});
    $channel->addChild($item);
    $channel->appendTextNode("\n");
  }
  return $doc->toString();
}

1;
