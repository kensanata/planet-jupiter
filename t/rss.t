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

require "./jupiter.pl";

my $id = int(rand(1000));
mkdir("test-$id");

my $port = 10000 + $id;

write_binary("test-$id/rss2sample.opml", <<"EOT");
<opml version="2.0">
  <body>
    <outline title="RSS 2.0 Sample File"
             xmlUrl="http://127.0.0.1:$port/"/>
  </body>
</opml>
EOT

my $rss = read_binary("t/rss2sample.xml");

use Mojo::Server::Daemon;

my $daemon = Mojo::Server::Daemon->new(listen => ["http://*:$port"]);
$daemon->on(request => sub {
  my ($daemon, $tx) = @_;
  # Response
  $tx->res->code(200);
  $tx->res->headers->content_type('application/xml');
  $tx->res->body($rss);
  # Resume transaction
  $tx->resume;
});
$daemon->start;

Jupiter::update_cache("test-$id/rss2sample.opml");

$daemon->stop;

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

$messages = decode_json read_binary "test-$id/rss2sample.json";
is($messages->{"http://127.0.0.1:$port/"}->{code}, "206", "HTTP status code is 206");
is($messages->{"http://127.0.0.1:$port/"}->{message}, "No feed updates in 90 days",
   "HTTP status message says no updates in a long time");
is($messages->{"http://127.0.0.1:$port/"}->{title}, "Liftoff News", "Title was taken from the feed");

done_testing();