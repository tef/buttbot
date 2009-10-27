#!/usr/bin/perl
use strict;
use warnings;

use Butts qw(buttify);

my $butt = shift;
$butt = $butt || "butt";

while(<>) {
chomp;
print join(" ", buttify($butt,split(/\s+/, $_)))."\n";
}
