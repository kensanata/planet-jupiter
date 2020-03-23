# Planet Jupiter

This program is used to pull together the latest updates from a bunch of other
sites and display them on a single web page. The sites we get our updates from
are defined in an OPML file.

## What is this?

This is a [Planet](https://en.wikipedia.org/wiki/Planet_(software)), a
"river of news" aggregator. It collects updates from the RSS and Atom
feeds of other sites and generates a HTML file. If you do this for a
website you host, other people read the same news. This is ideal for a
community centred around a particular topic (a program, a language, a
field, a hobby).

A [regular aggregator](https://en.wikipedia.org/wiki/News_aggregator)
treats all the items in the feeds it is subscribed to like incoming
mail: you read them, perhaps you can group the feeds into categories,
maybe you can "star" items you like, and probably there's an unread
count.

A "river of news" aggregator is different because most of the time
it's *public*. The properties:

- items are in reverse-chronological order (newest at the top)
- excerpts are of approximately equal *size* (a fixed number of words)
- excerpts are of approximately equal *shape* (all formatting is removed)
- skimming items happens by simply scrolling up and down (no pagination)
- there are no accounts for readers
- there is no count of unread items
- it only goes back so far

Essentially, it removes the pressure of "catching up". It's designed
to make it *impossible* to catch up. You just dip your foot into the
river every now and then.

See also Dave Winer's blog post from 2014,
[What is a River of News Aggregator?](http://scripting.com/2014/06/02/whatIsARiverOfNewsAggregator.html)

## Alternatives

Other "river of news" aggregators:

* [Planet Venus](http://intertwingly.net/code/venus/), written in Python 2
* [Planet Pluto](https://github.com/feedreader/), written in Ruby
* [Moonmoon](http://moonmoon.org/), written in PHP

## Dependencies

To run Jupiter on Debian:

- `libmodern-perl-perl` for [Modern::Perl](https://metacpan.org/pod/Modern::Perl)
- `libmojolicious-perl` for [Mojo::Template](https://metacpan.org/pod/Mojo::Template) and [Mojo::UserAgent](https://metacpan.org/pod/Mojo::UserAgent)
- `libxml-libxml-perl` for [XML::LibXML](https://metacpan.org/pod/XML::LibXML)
- `libfile-slurper-perl` for [File::Slurper](https://metacpan.org/pod/File::Slurper)
- `libcpanel-json-xs-perl` for [Cpanel::JSON::XS](https://metacpan.org/pod/Cpanel::JSON::XS)
- `libdatetime-perl` for [DateTime](https://metacpan.org/pod/DateTime)
- `libdatetime-format-mail-perl` for [DateTime::Format::Mail](https://metacpan.org/pod/DateTime::Format::Mail)
- `libdatetime-format-iso8601-perl` for [DateTime::Format::ISO8601](https://metacpan.org/pod/DateTime::Format::ISO8601)

Unfortunately, [Mojo::UserAgent::Role::Queued](https://metacpan.org/pod/Mojo::UserAgent::Role::Queued) isn't packaged for Debian.
Therefore, let's build it and install it as a Debian package.

    sudo apt-get install libmodule-build-tiny-perl
    sudo apt-get install dh-make-perl
    sudo dh-make-perl --build --cpan Mojo::UserAgent::Role::Queued
    dpkg --install libmojo-useragent-role-queued-perl_1.15-1_all.deb

To generate the `README.md` from the source file: `libpod-markdown-perl`.

## The OPML file

You **need** an OPML file. It's an XML file linking to _feeds_. Here's an
example listing just one feed. In order to add more, add more `outline`
elements with the `xmlUrl` attribute. The exact order and nesting does not
matter. People can _import_ these OPML files into their own feed readers and
thus it may make sense to spend a bit more effort in making it presentable.

    <opml version="2.0">
      <body>
        <outline title="Alex Schroeder"
                 xmlUrl="https://alexschroeder.ch/wiki?action=rss"/>
      </body>
    </opml>

## Update the feeds in your cache

This is how you update the feeds in a file called `feed.opml`. It downloads all
the feeds linked to in the OPML file and stores them in the cache directory.

    perl jupiter.pl update feed.opml

The directory used to keep a copy of all the feeds in the OPML file has the same
name as the OPML file but without the .opml extension. In other words, if your
OPML file is called `feed.opml` then the cache directory is called `feed`.

This operation takes long because it requests an update from all the sites
listed in your OPML file. Don't run it too often or you'll annoy the site
owners.

The OPML file must use the .opml extension. You can update the feeds for
multiple OPML files in one go.

## Generate the HTML

This is how you generate the `index.html` file based on the feeds of your
`feed.opml`. It assumes that you have already updated all the feeds (see
above).

    perl jupiter.pl html feed.opml

The file generation uses a template, `template.html`. It is written for
`Mojo::Template`. The default templates use other files, such as the logo, the
feed icon, a CSS file, and a small Javascript snippet to enable navigation using
the `J` and `K` keys.

You can specify a different HTML file to generate:

    perl jupiter.pl html your.html feed.opml

If you specify two HTML files, the first is the HTML file to generate and the
second is the template to use:

    perl jupiter.pl html your.html your-template.html feed.opml

## Generate the RSS feed

This happens at the same time as when you generate the HTML. It takes all the
entries that are being added to the HTML and puts the into a feed. If you don't
specify an HTML file, it tries to use `feed.rss` as the template for the feed
and it writes all the entries into a file called `feed.xml`. Again, the
template is written for `Mojo::Template`.

You can specify up to two XML, RSS or ATOM files. The first is the name of the
feed to generate, the second is the template to use:

    perl jupiter.pl html atom.xml template.xml planet.html template.html feed.opml

For more information about feeds, take a look at the specifications:

- RSS 2.0, [https://cyber.harvard.edu/rss/rss.html](https://cyber.harvard.edu/rss/rss.html)
- Atom Syndication, [https://tools.ietf.org/html/rfc4287](https://tools.ietf.org/html/rfc4287)

## Why separate the two steps?

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
[https://alexschroeder.ch/cgit/planet/about/](https://alexschroeder.ch/cgit/planet/about/)

## What about the JSON file?

There's a JSON file that gets generated and updated as you run Planet Jupiter.
It's name depends on the OPML files used. It records metadata for every feed in
the OPML file that isn't stored in the feeds themselves.

- `message` is the HTTP status message, or a similar message such as "No
entry newer than 90 days." This is set when update the feeds in your cache.
- `message` is the HTTP status code; this code could be the real status
code from the server (such as 404 for a "not found" status) or one generated by
Jupiter such that it matches the status message (such as 206 for a "partial
content" status when there aren't any recent entries in the feed). This is set
when update the feeds in your cache.
- `title` is the site's title. When you update the feeds in your cache, it
is taken from the OPML file. That's how the feed can have a title even if the
download failed. When you generate the HTML, the feeds in the cache are parsed
and if a title is provided, it is stored in the JSON file and overrides the
title in the OPML file.
- `link` is the site's link for humans. When you generate the HTML, the
feeds in the cache are parsed and if a title is provided, it is stored in the
JSON file and overrides the link in the OPML file.
- `last_modified` and `etag` are two headers used for caching
from the HTTP response that cannot be changed by data in the feed.

If we run into problems downloading a feed, this setup allows us to still link
to the feeds that aren't working, using their correct names, and describing the
error we encountered.

## Logging

Use the `--log=LEVEL` to set the log level. Valid values for LEVEL are debug,
info, warn, error, and fatal.

## Writing templates

The page template is called with three hash references: `globals`, `feeds`,
and `entries`. The keys of these three hash references are documented below.

The technical details of how to write the templates are documented in the man
page for [Mojo::Template](https://metacpan.org/pod/Mojo::Template).

### Globals

There are not many global keys.

**date** is the the publication date of the HTML page, in ISO date format:
YYYY-MM-DD.

**files** is the list of OPML files used.

### Writing templates for feeds

Feeds have the following keys available:

**title** is the title of the feed.

**url** is the URL of the feed (RSS or Atom). This is not the link to the site!

**link** is the URL of the web page (HTML). This is the link to the site.

**opml\_file** is the file name where this feed is listed.

**cache\_dir** is the directory where this feed is cached.

**message** is the HTTP status message or other warning or error that we got
while fetching the feed.

**code** is the HTTP status code we got while fetching the feed.

**doc** is the [XML::LibXML::Document](https://metacpan.org/pod/XML::LibXML::Document). Could be either Atom or RSS!

### Writing templates for entries

Entries have the following keys available:

**title** is the title of the post.

**link** is the URL to the post on the web (probably a HTML page).

**blog\_title** is the title of the site.

**blog\_link** is the URL for the site on the web (probably a HTML page).

**blog\_url** is the URL for the site's feed (RSS or Atom).

**authors** are the authors (or the Dublin Core contributor), a list of strings.

**date** is the publication date, as a DateTime object.

**day** is the publication date, in ISO date format: YYYY-MM-DD.

**content** is the full post content, as string or encoded HTML.

**excerpt** is the post content, limited to 500 characters, with paragraph
separators instead of HTML elements, as HTML.

**categories** are the categories, a list of strings.

**element** is for internal use only. It contains the [XML::LibXML::Element](https://metacpan.org/pod/XML::LibXML::Element)
object. This could be RSS or Atom!

**feed** is for internal use only. It's a reference to the feed this entry
belongs to.
