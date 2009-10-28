#!/usr/bin/perl
use strict;
use warnings;

use Butts;

my $butt = $ARGV[0] || "butt";
my $buttifier = Butts->new(meme => $butt, debug => 1,
                            replace_freq => $ARGV[1] // 0.5);

print "butt repeat rate is " . $buttifier->{replace_freq} . $/;
while(<STDIN>) {

    # The old way

    # chomp
    # print join(" ", $buttifier->buttify(split(/\s+/, $_)))."\n";

    # The new way

    print $buttifier->buttify_string, $/;
}
