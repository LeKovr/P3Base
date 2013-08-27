#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

open LIST, "find lib/ -name '*.pm' |";
my @tests = map { chomp; $_ } <LIST>;
close LIST;

plan tests => scalar(@tests);

use lib qw(lib);

foreach my $lib (@tests) {
  $lib =~ s|lib/(.+)\.pm$|$1|;
  $lib =~ s|/|::|g;
  eval "use $lib";
  is($@, '', $lib);
}

# -----------------------------------------------------------------------------
