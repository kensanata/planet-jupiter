
Planet Jupiter
==============

This program is used to pull together the latest updates from a bunch
of other sites and display them on a single web page.

The web page is a static HTML web page. The program is called from a
job, once every few hours. It checks the feeds (RSS or Atom) of the
various sites it's following and recreates the web page.

The sites it is following are pulled from an OPML file. Here's an
example of an OPML file:

```xml
<opml version="2.0">
  <body>
    <outline title="Other Blogs">
      <outline title="Alex Schroeder" xmlUrl="https://alexschroeder.ch/wiki/feed/full/RPG"/>
      <outline title="The Alexandrian" xmlUrl="https://thealexandrian.net/feed"/>
      <outline title="The Bottomless Sarcophagus" xmlUrl="https://bottomlesssarcophagus.blogspot.com/feeds/posts/default"/>
      <outline title="Wanderer Bill’s Journal" xmlUrl="https://betola.de/wandererbill/feed/"/>
    </outline>
  </body>
</opml>
```

*Planet Jupiter* simple searches the OPML file for outline elements
with the `xmlURL` attribute and reads the feed from there. The file is
assumed to have the extension `opml`.

The feeds are all stored on the file system in a directory called like
the OPML file, minus the extension. If the OPML file is called
`feeds.opml` then the cache directory is called `feeds`.

