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
   my $rep = int(@words/11)+1;
   my $c = 0;

   # sort indicies by word length
   my @longest = map { $_->[0] }
   sort { $b->[1] <=> $a->[1] }
   map { [$c++ , length($_) ] } @words;
   $c=0;

   # remove stop words
   @longest = grep {
   my $word = $words[$_]; 
   my $wordmeta = quotemeta($word);
   $word !~ /^[\d\W+]+$/ && !grep(/$wordmeta/i, @stopwords)} @longest;
   # print "Words in order: ".join(",",map {$words[$_]} @longest)."\n";

   # create weighed index array of words by length
   my @index = map {$longest[$_]} _weighed_index_array(scalar @longest);
   #print "Weighed words in order: ".join(",",map {$words[$_]} @index)."\n";

   _shuffle(\@index) if (scalar @index);
   while ($c < $rep) {
        $words[$index[$c]]= _buttsub($words[$index[$c]]);
	@index = grep {$_ != $index[$c]} @index;
        $c++;
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

## perl cookbook
# fisher_yates_shuffle( \@array ) : generate a random permutation
# of @array in place
sub _shuffle {
    my $array = shift;
    my $i;
    for ($i = @$array; --$i; ) {
        my $j = int rand ($i+1);
        next if $i == $j;
        @$array[$i,$j] = @$array[$j,$i];
    }
}

sub _weighed_index_array {
	my $len = shift;
        my $c = 0;
        my $n = $len;
        my @a = ();
        while ($c < $len) {
           push @a, ($c) x ($n*$n);
           $n--;
           $c++;
        }
	return @a;
}

1;
__END__
