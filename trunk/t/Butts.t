use strict;
use warnings;

use Test::More tests => 12;

BEGIN { use_ok('Butts', qw(buttify)); }

can_ok('Butts', qw(buttify));

for (1 .. 10) {
  my @sample = buttify(qw(The rain in Spain falls mainly on the plain.));
  {
    local $" = ' ';
    print "@sample\n";
  }

  my $has_butt = grep { /butt/i } @sample;

  ok($has_butt, 'sample has butt');
}
