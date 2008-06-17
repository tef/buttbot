use Test::More tests => 3;

BEGIN { use_ok('Butts', qw(buttify)); }

can_ok('Butts', qw(buttify));

my @sample = buttify(qw(The rain in Spain falls mainly on the plain.));
{
	local $" = ' ';
	print "@sample\n";
}

my $has_butt = grep { /butt/i } buttify(@sample);

ok($has_butt);
