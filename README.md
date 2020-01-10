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
