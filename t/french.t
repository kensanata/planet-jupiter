# Copyright (C) 2021  Alex Schroeder <alex@gnu.org>

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

package Jupiter;
use Modern::Perl;
use Test::More tests => 2;

require './script/jupiter';

is(french("mar., 10 nov. 2020 18:14:00 +0100"), "Tue, 10 Nov 2020 18:14:00 +0100");

my $doc = XML::LibXML->load_xml(string => "<pubDate>mar., 10 nov. 2020 18:14:00 +0100</pubDate>");
is(updated($doc), "2020-11-10T18:14:00");
