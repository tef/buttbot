use strict;
use warnings;

my @FILES = qw(
	buttbot.pl
	Butts.pm
	t/Butts.t
	critique.pl
);

use Perl::Critic;
my $critic = new Perl::Critic;

for my $file (@FILES) {
	print "Critiquing $file...\n";
	print $critic->critique($file);
}