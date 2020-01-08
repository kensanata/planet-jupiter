#! /usr/bin/env perl
# Copyright (C) 2020  Alex Schroeder <alex@gnu.org>

# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see <http://www.gnu.org/licenses/>.

package Jupiter;
use Modern::Perl;
use File::Slurp;
use Mojo::UserAgent;
use XML::LibXML;
use utf8; # in case anybody ever adds UTF8 characters to the source

update_cache();

sub update_cache {
  my $feeds = read_opml();
  my $ua = Mojo::UserAgent->new;
  my @promises;
  my @dir;
  my @url;
  my @files;
  for my $file (keys %$feeds) {
    my $dir = $file;
    $dir =~ s/\.(opml|xml)$// or die "$file doesn't end in .opml or .xml\n";
    mkdir $dir unless -d $dir;
    # remember the files already here
    push(@files, <"$dir/*">);
    for my $url (@{$feeds->{$file}}) {
      push(@dir, $dir);
      push(@url, $url);
      push(@promises, $ua->get_p($url));
    }
  }
  my %seen;
  say "Fetching feeds...";
  Mojo::Promise->all(@promises)->then(sub {
    my @tx = @_;
    for my $tx (@tx) {
      my $feed = $tx->[0]->result->body;
      my $dir = shift(@dir);
      my $url = shift(@url);
      my $file = $dir . "/" . url_to_file($url);
      $seen{$file} = 1;
      write_file($file, $feed) or die "Unable to write $file\n";
    }
  })->wait;
  say "Remove unused files from the cache...";
  # FIXME
}

sub url_to_file {
  my $url = shift;
  $url =~ s/[\/?&:]+/-/g;
  return $url;
}

# Return a hash mapping filename → list of feed URLs
sub read_opml {
  my %feeds;
  for my $file (@ARGV) {
    open my $fh, '<', $file;
    binmode $fh;
    my $doc = XML::LibXML->load_xml(IO => $fh);
    my @nodes = $doc->findnodes('//outline/@xmlUrl');
    my @feeds = map { $_->value() } @nodes;
    $feeds{$file} = \@feeds;
  }
  return \%feeds;
}
