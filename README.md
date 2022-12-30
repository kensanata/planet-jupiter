# NAME

jupiter - turn a list of feeds into a HTML page, a river of news

# SYNOPSIS

To update the feeds from one or more OPML files:

**jupiter update** _feed.opml_ … \[_/regex/_ …\]

To generate `index.html`:

**jupiter html** _feed.opml_

# DESCRIPTION

Planet Jupiter is used to pull together the latest updates from a bunch of other
sites and display them on a single web page, the "river of news". The sites we
get our updates from are defined in an OPML file.

A river of news, according to Dave Winer, is a feed aggregator. New items appear
at the top and old items disappear at the bottom. When it's gone, it's gone.
There is no count of unread items. The goal is to fight the _fear of missing
out_ (FOMO).

Each item looks similar to every other: headline, link, an extract, maybe a date
and an author. Extracts contain but the beginning of the article's text; all
markup is removed; no images. The goal is to make it the page easy to skim.
Scroll down until you find something interesting and follow the link to the
original article if you want to read it.

## The OPML file

You **need** an OPML file. It's an XML file linking to _feeds_. Here's an
example listing just one feed. In order to add more, add more `outline`
elements with the `xmlUrl` attribute. The exact order and nesting does not
matter. People can _import_ these OPML files into their own feed readers and
thus it may make sense to spend a bit more effort in making it presentable.

```xml
<opml version="2.0">
  <body>
    <outline title="Alex Schroeder" xmlUrl="https://alexschroeder.ch/wiki?action=rss"/>
  </body>
</opml>
```

## Update the feeds in your cache

This is how you update the feeds in a file called `feed.opml`. It downloads all
the feeds linked to in the OPML file and stores them in the cache directory.

```sh
jupiter update feed.opml
```

The directory used to keep a copy of all the feeds in the OPML file has the same
name as the OPML file but without the .opml extension. In other words, if your
OPML file is called `feed.opml` then the cache directory is called `feed`.

This operation takes long because it requests an update from all the sites
listed in your OPML file. Don't run it too often or you'll annoy the site
owners.

The OPML file must use the .opml extension. You can update the feeds for
multiple OPML files in one go.

## Adding just one feed

After a while, the list of feeds in your OPML starts getting unwieldy. When you
add a new feed, you might not want to fetch all of them. In this case, provide a
regular expression surrounded by slashes to the `update` command:

```sh
jupiter update feed.opml /example/
```

Assuming a feed with a URL or title that matches the regular expression is
listed in your OPML file, only that feed is going to get updated.

There is no need to escape slashes in the regular expression: `//rss/` works
just fine. Beware shell escaping, however. Most likely, you need to surround the
regular expression with single quotes if it contains spaces:

```sh
jupiter update feed.opml '/Halberds & Helmets/'
```

Notice how we assume that named entities such as `&amp;` have already been
parsed into the appropriate strings.

## Generate the HTML

This is how you generate the `index.html` file based on the feeds of your
`feed.opml`. It assumes that you have already updated all the feeds (see
above).

```sh
jupiter html feed.opml
```

See ["OPTIONS"](#options) for ways to change how the HTML is generated.

## Generate the RSS feed

This happens at the same time as when you generate the HTML. It takes all the
entries that are being added to the HTML and puts the into a feed.

See ["OPTIONS"](#options) for ways to change how the HTML is generated.

## Why separate the two steps?

The first reason is that tinkering with the templates involves running the
program again and again, and you don't want to contact all the sites whenever
you update your templates.

The other reason is that it allows you to create subsets. For example, you can
fetch the feeds for three different OPML files:

```sh
jupiter update osr.opml indie.opml other.opml
```

And then you can create three different HTML files:

```sh
jupiter html osr.html osr.opml
jupiter html indie.html indie.opml
jupiter html rpg.html osr.opml indie.opml other.opml
```

For an example of how it might look, check out the setup for the planets I run.
[https://alexschroeder.ch/cgit/planet/about/](https://alexschroeder.ch/cgit/planet/about/)

## What about the JSON file?

There's a JSON file that gets generated and updated as you run Planet Jupiter.
It's name depends on the OPML files used. It records metadata for every feed in
the OPML file that isn't stored in the feeds themselves.

`message` is the HTTP status message, or a similar message such as "No entry
newer than 90 days." This is set when update the feeds in your cache.

`message` is the HTTP status code; this code could be the real status code from
the server (such as 404 for a "not found" status) or one generated by Jupiter
such that it matches the status message (such as 206 for a "partial content"
status when there aren't any recent entries in the feed). This is set when
update the feeds in your cache.

`title` is the site's title. When you update the feeds in your cache, it is
taken from the OPML file. That's how the feed can have a title even if the
download failed. When you generate the HTML, the feeds in the cache are parsed
and if a title is provided, it is stored in the JSON file and overrides the
title in the OPML file.

`link` is the site's link for humans. When you generate the HTML, the feeds in
the cache are parsed and if a link is provided, it is stored in the JSON file.
If the OPML element contained a `htmlURL` attribute, however, that takes
precedence. The reasoning is that when a podcast is hosted on a platform which
generates a link that you don't like and you know the link to the human-readable
blog elsehwere, use the `htmlURL` attribute in the OPML file to override this.

`last_modified` and `etag` are two headers used for caching from the HTTP
response that cannot be changed by data in the feed.

If we run into problems downloading a feed, this setup allows us to still link
to the feeds that aren't working, using their correct names, and describing the
error we encountered.

## Logging

Use the `--log=LEVEL` to set the log level. Valid values for LEVEL are debug,
info, warn, error, and fatal.

# LICENSE

GNU Affero General Public License

# INSTALLATION

Using `cpan`:

```sh
cpan App::jupiter
```

Manual install:

```sh
perl Makefile.PL
make
make install
```

## Dependencies

To run Jupiter on Debian we need:

`libmodern-perl-perl` for [Modern::Perl](https://metacpan.org/pod/Modern%3A%3APerl)

`libmojolicious-perl` for [Mojo::Template](https://metacpan.org/pod/Mojo%3A%3ATemplate), [Mojo::UserAgent](https://metacpan.org/pod/Mojo%3A%3AUserAgent), [Mojo::Log](https://metacpan.org/pod/Mojo%3A%3ALog),
[Mojo::JSON](https://metacpan.org/pod/Mojo%3A%3AJSON), and [Mojo::Util](https://metacpan.org/pod/Mojo%3A%3AUtil)

`libxml-libxml-perl` for [XML::LibXML](https://metacpan.org/pod/XML%3A%3ALibXML)

`libfile-slurper-perl` for [File::Slurper](https://metacpan.org/pod/File%3A%3ASlurper)

`libdatetime-perl` for [DateTime](https://metacpan.org/pod/DateTime)

`libdatetime-format-mail-perl` for [DateTime::Format::Mail](https://metacpan.org/pod/DateTime%3A%3AFormat%3A%3AMail)

`libdatetime-format-iso8601-perl` for [DateTime::Format::ISO8601](https://metacpan.org/pod/DateTime%3A%3AFormat%3A%3AISO8601)

Unfortunately, [Mojo::UserAgent::Role::Queued](https://metacpan.org/pod/Mojo%3A%3AUserAgent%3A%3ARole%3A%3AQueued) isn't packaged for Debian.
Therefore, let's build it and install it as a Debian package.

```sh
sudo apt-get install libmodule-build-tiny-perl
sudo apt-get install dh-make-perl
sudo dh-make-perl --build --cpan Mojo::UserAgent::Role::Queued
dpkg --install libmojo-useragent-role-queued-perl_1.15-1_all.deb
```

To generate the `README.md` from the source file, you need `pod2markdown`
which you get in `libpod-markdown-perl`.

# FILES

There are a number of files in the `share` directory which you can use as
starting points.

`template.html` is the HTML template.

`default.css` is a small CSS file used by `template.html`.

`personalize.js` is a small Javascript file used by `template.html` used to
allow visitors to jump from one article to the next using `J` and `K`.

`jupiter.png` is used by `template.html` as the icon.

`jupiter.svg` is used by `template.html` as the logo.

`feed.png` is used by `template.html` as the icon for the feeds in the
sidebar.

`feed.rss` is the feed template.

# OPTIONS

HTML generation uses a template, `template.html`. It is written for
`Mojo::Template` and you can find it in the `share` directory of your
distribution. The default templates use other files, such as the logo, the feed
icon, a CSS file, and a small Javascript snippet to enable navigation using the
`J` and `K` keys (see above).

You can specify a different HTML file to generate:

**jupiter html** _your.html feed.opml_

If you specify two HTML files, the first is the HTML file to generate and the
second is the template to use. Both must use the `.html` extension.

**jupiter html** _your.html your-template.html feed.opml_

Feed generation uses a template, `feed.rss`. It writes all the entries into a
file called `feed.xml`. Again, the template is written for `Mojo::Template`.

You can specify up to two XML, RSS or ATOM files. They must uses one of these
three extensions: `.xml`, `.rss`, or `.atom`. The first is the name of the
feed to generate, the second is the template to use:

**jupiter html** _atom.xml template.xml planet.html template.html feed.opml_

In the above case, Planet Jupiter will write a feed called `atom.xml` based on
`template.xml` and a HTML file called `planet.html` based on `template.html`,
using the cached entries matching the feeds in `feed.opml`.

# TEMPLATES

The page template is called with three hash references: `globals`, `feeds`,
and `entries`. The keys of these three hash references are documented below.
The values of these hashes are all _escaped HTML_ except where noted (dates and
file names, for example).

The technical details of how to write the templates are documented in the man
page for [Mojo::Template](https://metacpan.org/pod/Mojo%3A%3ATemplate).

## Globals

There are not many global keys.

**date** is the the publication date of the HTML page, in ISO date format:
YYYY-MM-DD.

**files** is the list of OPML files used.

## Writing templates for feeds

Feeds have the following keys available:

**title** is the title of the feed.

**url** is the URL of the feed (RSS or Atom). This is not the link to the site!

**link** is the URL of the web page (HTML). This is the link to the site.

**opml\_file** is the file name where this feed is listed.

**cache\_dir** is the directory where this feed is cached.

**message** is the HTTP status message or other warning or error that we got
while fetching the feed.

**code** is the HTTP status code we got while fetching the feed.

**doc** is the [XML::LibXML::Document](https://metacpan.org/pod/XML%3A%3ALibXML%3A%3ADocument). Could be either Atom or RSS!

## Writing templates for entries

Entries have the following keys available:

**title** is the title of the post.

**link** is the URL to the post on the web (probably a HTML page).

**blog\_title** is the title of the site.

**blog\_link** is the URL for the site on the web (probably a HTML page).

**blog\_url** is the URL for the site's feed (RSS or Atom).

**authors** are the authors (or the Dublin Core contributor), a list of strings.

**date** is the publication date, as a DateTime object.

**day** is the publication date, in ISO date format: YYYY-MM-DD, for the UTC
timezone. The UTC timezone is picked so that the day doesn't jump back and forth
when sorting entries by date.

**content** is the full post content, as string or encoded HTML.

**excerpt** is the post content, limited to 500 characters, with paragraph
separators instead of HTML elements, as HTML. It is not encoded because the idea
is that it only gets added to the HTML and not to the feed, and the HTML it
contains is very controlled (only the pilcrow sign inside a span to indicate
paragraph breaks).

**categories** are the categories, a list of strings.

**element** is for internal use only. It contains the [XML::LibXML::Element](https://metacpan.org/pod/XML%3A%3ALibXML%3A%3AElement)
object. This could be RSS or Atom!

**feed** is for internal use only. It's a reference to the feed this entry
belongs to.

# SEE ALSO

OPML 2.0, [http://dev.opml.org/spec2.html](http://dev.opml.org/spec2.html)

RSS 2.0, [https://cyber.harvard.edu/rss/rss.html](https://cyber.harvard.edu/rss/rss.html)

Atom Syndication, [https://tools.ietf.org/html/rfc4287](https://tools.ietf.org/html/rfc4287)

River of News,
[http://scripting.com/2014/06/02/whatIsARiverOfNewsAggregator.html](http://scripting.com/2014/06/02/whatIsARiverOfNewsAggregator.html)
