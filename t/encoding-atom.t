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
save_opml('rss2sample.opml');

my $atom = <<'EOT';
<?xml version='1.0' encoding='UTF-8'?>
<feed xmlns='http://www.w3.org/2005/Atom'>
<updated>2019-12-21T10:08:43.170-08:00</updated>
<title type='text'>Schröder</title>
<author><name>Schröder</name><email>noreply@blogger.com</email></author>
<entry>
<published>2019-12-21T10:08:00.002-08:00</published>
<updated>2019-12-21T10:08:43.064-08:00</updated>
<title type='text'>Schröder &amp; Schröder</title>
<content type='html'>Hello Schröder!</content>
</entry>
</feed>
EOT

start_daemon(encode_utf8 $atom);

Jupiter::update_cache("test-$id/rss2sample.opml");

stop_daemon();

write_binary "test-$id/rss2sample-page.html", read_binary "page.html";
write_binary "test-$id/rss2sample-post.html", read_binary "post.html";

Jupiter::make_html("test-$id/rss2sample.html", "test-$id/rss2sample.opml");

ok(-f "test-$id/rss2sample.html", "HTML was generated");
my $doc = XML::LibXML->load_html(location => "test-$id/rss2sample.html");
is($doc->findvalue('//h3/a[position()=2]'), "Schröder & Schröder", "Encoded item title matches");
is($doc->findvalue('//li/a[position()=2]'), "Schröder", "Encoded feed title matches");
is($doc->findvalue('//h3/a[position()=1]'), "Schröder", "Encoded feed title matches again");

done_testing;
