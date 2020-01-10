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

The file generation uses two templates, `body.html` for the overall structure
and `post.html` for each individual post. These are written for
`Mojo::Template`. The default templates use other files, such as the logo, a
CSS file, and a small Javascript snippet to enable navigation using the `J` and
`K` keys.

## Why separate the two steps?

The first reason is that tinkering with the templates involves running the
program again and again, and you don't want to contact all the sites whenever
you update your tempaltes.

The other reason is that it allows you to create subsets. For example, you can
fetch the feeds for three different OPML files:

    perl jupiter.pl update osr.opml indie.opml other.opml

And then you can create three different HTML files:

    perl jupiter.pl html osr.html osr.opml
    perl jupiter.pl html indie.html indie.opml
    perl jupiter.pl html rpg.html osr.opml indie.opml other.opml
