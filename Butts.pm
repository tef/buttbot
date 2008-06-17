package Butts;

use strict;
use warnings;

use Exporter;
use List::Util qw(max);
use TeX::Hyphen;

use constant STOPWORDS_FILE => 'stopwords';

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(buttify);

our $hyp;
if (-e "hyphen.tex") {
    $hyp = new TeX::Hyphen file => "hyphen.tex";
} else {
    $hyp = new TeX::Hyphen;
}

our @stopwords;
if (-f STOPWORDS_FILE && -r STOPWORDS_FILE) {
    open my($fh), STOPWORDS_FILE;
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
   my $wordmeta = quotemeta($word);
   $word !~ /^[\d\W+]+$/ && !grep(/$wordmeta/i, @stopwords)} @longest;
   # print "Words in order: ".join(",",map {$words[$_]} @longest)."\n";

   # create weighed index array of words by length
	my @indices = map {$longest[$_]} _weighted_indices(scalar @longest);
	#print "Weighed words in order: ".join(",",map {$words[$_]} @indices)."\n";

	_shuffle(\@indices) if @indices;

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
   my ($lp, $actual_word, $rp) =
       ($word =~ /^([^A-Za-z]*)(.*?)([^A-Za-z]*)$/);

   return $word unless ($actual_word);
   
   my @points = $hyp->hyphenate($actual_word);
   unshift(@points,0);

   my $factor = 2;
   my $len = scalar @points;
   my $replace = $len -1 - int(rand($len ** $factor) ** (1.0/$factor));
   push @points,length($actual_word);

   my $l = $points[$replace];
   my $r = $points[$replace+1]- $l ;
   
   while (substr($actual_word,$l+$r,1) eq "t") { $r++; }
   while ($l > 0 && substr($actual_word,$l-1,1) eq "b") { $l--; }
   my $sub = substr($actual_word,$l,$r);
   my $butt ="butt";

   if ($sub eq uc $sub) {
     $butt = "BUTT";
   } elsif ($sub =~/^[A-Z]/) {
     $butt = "Butt";
   } 
   
   substr($actual_word,$l,$r) = $butt;
   return join('', $lp, $actual_word, $rp);
}

# fisher yates shuffle
sub _shuffle {
	my $array = shift;

	for (my $i = $#$array; $i > 0; --$i) {
		my $j = int rand($i + 1);

		next if $i == $j;
		@$array[$i, $j] = @$array[$j, $i];
	}
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
