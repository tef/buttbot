package Butts;

use strict;
use warnings;

use Exporter;
use List::Util qw(max shuffle);
use TeX::Hyphen;

use constant {
	DEBUG     => 0,
	STOPWORDS => 'stopwords',
	HYPHEN    => 'hyphen.tex',
};

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(buttify);

my $hyp = new TeX::Hyphen( -e HYPHEN ? (file => HYPHEN) : () );

my @stopwords;
if (-f STOPWORDS && -r STOPWORDS) {
	open my($fh), STOPWORDS;
	chomp(@stopwords = <$fh>);
} else {
	@stopwords = qw/a an and or but it in its It's it's the of you I i/;
}

sub buttify {
	my @words = @_;
	my $repetitions = int(@words / 11) + 1;
	my $c = 0;

	# sort indicies by word length
	my @longest = do {
		my $c;

		map  { $_->[0] }
		sort { $b->[1] <=> $a->[1] }
		map  { [$c++ , length($_) ] } @words;
	};

	# remove stop words
	@longest = grep {
		my $word = $words[$_]; 

		my $is_word = $word !~ /^[\d\W+]+$/;
		my $is_stop = grep /\Q$word\E/i, @stopwords;

		$is_word and not $is_stop;
	} @longest;

	print 'Words in order: ' . join(', ', map { $words[$_] } @longest) . "\n" if DEBUG;

	# create weighted index array of words by length
	my @indices = map { $longest[$_] } _weighted_indices(scalar @longest);

	print 'Weighted words in order: ' . join(', ', map { $words[$_] } @indices) . "\n" if DEBUG;

	@indices = shuffle(@indices) if @indices;

	for my $c (0 .. $repetitions - 1) {
		my $index = $indices[$c];

		$words[$index] = _buttsub($words[$index]);
		@indices = grep { $_ != $index } @indices;
	}

	return @words;
}

sub _buttsub {
	my $word = shift;

	# split off leading and trailing punctuation
	my ($lp, $actual_word, $rp) = $word =~ /^([^A-Za-z]*)(.*?)([^A-Za-z]*)$/;

	return $word unless $actual_word;
	
	my @points = (0, $hyp->hyphenate($actual_word));

	my $factor = 2;
	my $length = scalar @points;
	my $replace = $length - 1 - int(rand($length ** $factor) ** (1 / $factor));
	push @points, length($actual_word);

	my $l = $points[$replace];
	my $r = $points[$replace + 1] - $l;
	
	while (substr($actual_word, $l + $r, 1) eq 't') { $r++ }
	while ($l > 0 && substr($actual_word, $l - 1, 1) eq 'b') { $l-- }
	my $sub = substr($actual_word, $l, $r);
	my $butt = 'butt';

	if ($sub eq uc $sub) {
		$butt = 'BUTT';
	} elsif ($sub =~/^[A-Z]/) {
		$butt = 'Butt';
	} 
	
	substr($actual_word, $l, $r) = $butt;
	return "$lp$actual_word$rp";
}

sub _weighted_indices {
	my $length = shift;
	my $weight = $length;

	my @stack;
	for my $index (0 .. $length - 1) {
		push @stack, ($index) x ($weight ** 2);
		$weight--;
	}

	return @stack;
}

1;
