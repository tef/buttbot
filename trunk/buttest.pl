#!/usr/bin/perl
use strict;
use warnings;

use Butts qw(buttify);

while(<>) {
chomp;
print join(" ",buttify(split(/\s+/,$_)))."\n";
}
