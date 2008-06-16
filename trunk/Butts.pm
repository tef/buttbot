package Butts;

use strict;
use warnings;

use Exporter;
use List::Util qw(max);
use TeX::Hyphen;

our @ISA = qw(Exporter);

our @EXPORT_OK = qw(buttify);

our $hyp;
if ( -e "hyphen.tex") {
    $hyp = new TeX::Hyphen file=>"hyphen.tex";
} else {
    $hyp = new TeX::Hyphen ;
}
our @stopwords;
if ( -f "stopwords" && -r "stopwords") {
    my $fh;
    open $fh, "stopwords";
    @stopwords = <$fh>;
    chomp @stopwords;
    close $fh;
} else {
    @stopwords = qw/a an and or but it in its It's it's the of you I i/;
}

sub buttify {
   my (@words) = (@_);
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
   my @index = map {$longest[$_]} weighed_index_array(scalar @longest);
   #print "Weighed words in order: ".join(",",map {$words[$_]} @index)."\n";

   shuffle(\@index) if (scalar @index);
   while ($c < $rep) {
        $words[$index[$c]]=&buttsub($words[$index[$c]]);
	@index = grep {$_ != $index[$c]} @index;
        $c++;
  }

  return @words;
}

sub buttifynew {

   my (@words) = (@_);
   my $rep = int(@words/11)+1;
   my $c =0;

   # create list of weights and sort them.

   my $factor = max(map {length($_)} @words);

   # print "Factor : $factor \n"; 
   # sort indicies by word length
   
   my @pairs = map { [$c++,length($_)] } @words;
  
   #print "Pairs: ".join(",",map{$_->[0]." ".$_->[1]}@pairs)."\n";

   @pairs = grep {$words[$_->[0]] !~/^(a|an|and|or|but|it|in|the|of|you|I|i)$/} @pairs;

   #print "Stripped Pairs: ".join(",",map{$_->[0]." ".$_->[1]}@pairs)."\n";
  
   #@pairs = map { [$_->[0], rand($factor**$_->[1])**(1.0/$_->[1])]} @pairs;  
   # possible new algorithm but didn't have a nice as distribution. 
   # I should draw graphs.
   @pairs = map { [$_->[0], rand($_->[1]**$factor)**(1.0/$factor)]} @pairs;  
   #@pairs = map { [$_->[0], log(rand(exp($_->[1]))+1)]} @pairs;  

   #print "Weighed Pairs: ".join(",",map{$_->[0]." ".$_->[1]}@pairs)."\n";

   @pairs = sort { $b->[1] <=> $a->[1]} @pairs;  
   
   #print "Sorted Pairs: ".join(",",map{$_->[0]." ".$_->[1]}@pairs)."\n";
   
   my @index = map { $_->[0]} @pairs;
   
   $c=0;
   
   # remove stop words

   while ($c < $rep) {
        $words[$index[$c]]=&buttsub($words[$index[$c]]);
        $c++;
  }

  return @words;
}


sub buttsub {
   my $word = shift @_;

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
sub shuffle {
    my $array = shift;
    my $i;
    for ($i = @$array; --$i; ) {
        my $j = int rand ($i+1);
        next if $i == $j;
        @$array[$i,$j] = @$array[$j,$i];
    }
}

sub weighed_index_array {
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
