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

use Modern::Perl;
use Test::More;
use XML::Feed;
use XML::LibXML;
use File::Slurper qw(read_binary write_binary);
use Cpanel::JSON::XS;

do './t/test.pl';
my ($id, $port) = init();
save_opml('rss2sample.opml');

my $rss = read_binary("t/rss2sample.xml");

start_daemon($rss);

Jupiter::update_cache("test-$id/rss2sample.opml");

stop_daemon();

ok(-d "test-$id/rss2sample", "Cache was created");
ok(-f "test-$id/rss2sample/http-127.0.0.1-$port-", "Feed was cached");
is(read_binary("test-$id/rss2sample/http-127.0.0.1-$port-"), $rss, "Cached feed matches");
ok(-f "test-$id/rss2sample.json", "Messages were cached");

my $messages = decode_json read_binary "test-$id/rss2sample.json";
ok($messages->{"http://127.0.0.1:$port/"}, "Messages for this feed were cached");
is($messages->{"http://127.0.0.1:$port/"}->{code}, "200", "HTTP status code is 200");
is($messages->{"http://127.0.0.1:$port/"}->{message}, "OK", "HTTP status message is 'OK'");
is($messages->{"http://127.0.0.1:$port/"}->{title}, "RSS 2.0 Sample File", "Title was taken from the OPML file");

write_binary "test-$id/rss2sample-page.html", read_binary "page.html";
write_binary "test-$id/rss2sample-post.html", read_binary "post.html";

Jupiter::make_html("test-$id/rss2sample.html", "test-$id/rss2sample.opml");

ok(-f "test-$id/rss2sample.html", "HTML was generated");
my $html = read_binary "test-$id/rss2sample.html";
unlike($html, qr/syntax error at template/, "No syntax errors in the HTML");
my $doc = XML::LibXML->load_html(string => $html);
# these tests depend on page.html and post.html
ok($doc->findnodes('//a[@href="http://127.0.0.1:' . $port . '/"]'
		   . '/img[@src="feed.png"][@alt="(feed)"]'), "Sidebar feed link OK");
ok($doc->findnodes('//a[@class="message"][@title="No feed updates in 90 days"]'
		   . '[@href="http://liftoff.msfc.nasa.gov/"][text()="Liftoff News"]'),
   "Sidebar site link OK");

my $feed = XML::Feed->parse(\$rss);
for my $entry ($feed->entries) {
  my $found = $doc->findnodes('//h3/a[text()="' . ($entry->title||"Untitled") . '"]');
  ok($found, "Found in the HTML: " . ($entry->title||"Untitled"));
}

$messages = decode_json read_binary "test-$id/rss2sample.json";
is($messages->{"http://127.0.0.1:$port/"}->{code}, "206", "HTTP status code is 206");
is($messages->{"http://127.0.0.1:$port/"}->{message}, "No feed updates in 90 days",
   "HTTP status message says no updates in a long time");
is($messages->{"http://127.0.0.1:$port/"}->{title}, "Liftoff News", "Title was taken from the feed");

my $generated = XML::Feed->parse("test-$id/rss2sample.xml");
ok($generated, "A XML file was also generated");
for my $entry ($feed->entries) {
  my $found = grep { $entry->id eq $_->id } $generated->entries;
  ok($found, "Found in the feed: " . $entry->id);
}

done_testing;
