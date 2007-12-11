#!/usr/bin/perl
use strict;
use warnings;

require 'butts.pl';

while(<>) {
chomp;
print join(" ",buttify(split(/\s+/,$_)))."\n";
}
