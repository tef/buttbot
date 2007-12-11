#!/usr/bin/perl
require 'butts.pl';

while(<>) {
chomp;
print join(" ",buttify(split(/\s+/,$_)))."\n";
}
