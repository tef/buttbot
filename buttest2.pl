#!/usr/bin/perl
use strict;
use warnings;

use Butts2;

my $butt = $ARGV[0] || "butt";
my $buttifier = Butts2->new(meme => $butt, debug => 1,
                            replace_freq => $ARGV[1] || 0.5);

while(<STDIN>) {

    # The old way

    # chomp
    # print join(" ", $buttifier->buttify(split(/\s+/, $_)))."\n";

    # The new way

    print $buttifier->buttify_string, $/;
}
