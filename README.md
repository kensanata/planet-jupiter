# Planet Jupiter

This program is used to pull together the latest updates from a bunch of other
sites and display them on a single web page. The sites we get our updates from
are defined in an OPML file.

## The OPML file

You **need** an OPML file. It's an XML file linking to _feeds_. Here's an
example listing just one feed. In order to add more, add more `outline`
elements with the `xmlUrl` attribute. The exact order and nesting does not
matter. People can _import_ these OPML files into their own feed readers and
thus it may make sense to send a bit more effort in making it presentable.

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

## Generate the HTML

This is how you generate the `index.html` file based on the feeds of your
`feed.opml`. It assumes that you have already updated all the feeds (see
above).

    perl jupiter.pl html feed.opml

The file generation uses two templates, `page.html` for the overall structure
and `post.html` for each individual post. These are written for
`Mojo::Template`. The default templates use other files, such as the logo, a
CSS file, and a small Javascript snippet to enable navigation using the `J` and
`K` keys.

You can specify a different HTML file to generate:

    perl jupiter.pl html your.html feed.opml

In this case, the two templates used have names that are based on the name of
your HTML file: `your-page.html` for the overall structure and
`your-post.html` for each individual post.

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

## Dependencies

To run Jupiter on Debian: `libmojolicious-perl`, `libjson-perl`,
`libxml-libxml-perl`, `libfile-slurp-perl`, `libmodern-perl-perl`,
`libtime-parsedate-perl`, `libtimedate-perl`.

To generate the `README.md` from the source file: `libpod-readme-perl`.

## Writing templates

The page template is called with three hash references: globals, feeds, and
entries. The keys of these three hash references are documented below.

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

**url** is the URL of the feed. This is not the link to the site!

**opml\_file** is the file name where this feed is listed.

**cache\_dir** is the directory where this feed is cached.

**message** is the HTTP status message or other warning or error that we got
while fetching the feed.

**code** is the HTTP status code we got while fetching the feed.

### Writing templates for entries

Entries have the following keys available:

**title** is the title of the post.

**link** is the URL to the post on the web.

**blog\_title** is the title of the site.

**blog\_link** is the URL for the site on the web.

**author** is the author (or the Dublin Core contributor).

**day** is the publication date, in ISO date format: YYYY-MM-DD.

**excerpt** is the blog content, limited to 500 characters, with paragraph
separators instead of HTML elements.

**categories** are the categories, a list of strings.

**xml** is for internal use only. It contains the raw feed from which all other
information is extracted.

**seconds** is for internal use only. It's the publication date in seconds since
January 1, 1970.

**feed** is for internal use only. It's a reference to the feed this entry
belongs to.
