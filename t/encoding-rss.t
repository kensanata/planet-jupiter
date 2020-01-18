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

use utf8;
use Encode;
use Modern::Perl;
use Test::More;
use File::Slurper qw(write_binary read_binary write_text);

do './t/test.pl';
my ($id, $port) = init();

write_text("test-$id/rss2sample.opml", <<"EOT");
<opml version="2.0">
  <body>
    <outline title="العربيّة"
             xmlUrl="http://127.0.0.1:$port/"/>
  </body>
</opml>
EOT

my $rss = <<'EOT';
<?xml version="1.0" encoding='UTF-8'?>
<rss version="2.0">
   <channel>
      <title>Schröder</title>
      <link>https://alexschroeder.ch/</link>
      <pubDate>Mon, 13 Jan 2020 23:16:01 +0100</pubDate>
      <item>
         <title>السّلام عليك</title>
      </item>
   </channel>
</rss>
EOT

start_daemon(encode_utf8 $rss);

Jupiter::update_cache("test-$id/rss2sample.opml");

stop_daemon();

Jupiter::make_html("test-$id/rss2sample.html", "test-$id/rss2sample.xml", "test-$id/rss2sample.opml");

ok(-f "test-$id/rss2sample.html", "HTML was generated");
my $doc = XML::LibXML->load_html(location => "test-$id/rss2sample.html");
is($doc->findvalue('//h3/a[position()=2]'), "السّلام عليك", "Encoded item title matches");
is($doc->findvalue('//li/a[position()=2]'), "Schröder", "Encoded feed title matches");
is($doc->findvalue('//h3/a[position()=1]'), "Schröder", "Encoded feed title matches again");

done_testing;
