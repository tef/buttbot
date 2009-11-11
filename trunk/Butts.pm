=head1 NAME

Butts - replace random syllables with the arbitrary memes.

=head1 SYNOPSIS

  # with all defaults
  my $butter = Butts->new;
  $butter->buttify_string("hello there");

  # with all known options
  my $butter = Butts->new(
      meme => 'butt',
      replace_freq => (1/11),
      debug => 0,
      hyphen_file => 'hyphens.tex',
      stopwords_file => 'stopwords',
  );

  $butter->buttify(@tokens);
  $butter->buttify_string($string);


=head1 DESCRIPTION

Yes.

=cut

package Butts;

use strict;
use warnings;

use Math::Random;
use TeX::Hyphen;
use Data::Dumper;
use FindBin qw($RealBin);
use Carp;

use fields qw/replace_freq
              meme
              hyphen_file
              stopwords_file
              hyphenator
              stopwords
              debug
              _words
              _word_indices/;

=head1 METHODS

=cut

sub new {
    my Butts $self = shift;
    unless (ref $self) {
        $self = fields::new($self);
    }


    my %args = (hyphen_file    => "$RealBin/hyphen.tex",
                stopwords_file => "$RealBin/stopwords",
                debug          => 0,
                meme           => 'butt',
                replace_freq   => (1/11), # original value from tef.
                @_);

    foreach my $key (keys %args) {
        $self->{$key} = $args{$key};
    }

    $self->{hyphenator} = new TeX::Hyphen((file => $self->{hyphen_file}))
      or croak "Couldn't create TeX::Hyphen instance from " . $self->{hyphen_file};

    my @stopwords;
    if (open my $sfh, $self->{stopwords_file}) {
        chomp(@stopwords = <$sfh>);
        close $sfh;
    } else {
        carp "Couldn't read stopwords file "
          . $self->{stopwords_file} . ' ' . $!;
        @stopwords = qw/a an and or but it in its It's it's the of you I i/;
    }

    $self->{stopwords} = { map { lc($_) => 1 } @stopwords };

    return $self;
}

=head2 meme($value)

Method which sets / returns the current replacement meme.  If called without
additional arguments, it returns the current meme. Calling it with a scalar
replaces the old meme with a new one.

=cut

# accessors
sub meme {
    my $self = shift;
    if (@_) {
        $self->{meme} = $_[0];
    }
    return $self->{meme}
}

=head2 replace_freq($value)

Getter/Setter Method for the replacement frequency.  Value should be passed as a
fractional value, which corresponds to the number of words considered for meme
replacement via the following calculation:

=cut

sub replace_freq {
    my $self = shift;
    if (@_) {
        $self->{replace_freq} = $_[0];
    }
    return $self->{replace_freq}
}

# helpers
sub is_stop_word {
    my ($self, $word) = @_;
    return exists $self->{stopwords}->{lc($word)};
}

sub is_meme {
    my ($self, $word) = @_;
    return lc($word) eq lc($self->{meme});

}

sub split_preserving_whitespace {
    my ($string) = @_;

    my ($leading_ws, $remainder) = ($string =~ m/^(\s*)(.*)$/);
    $leading_ws //= '';

    my @all_split = split(/(\s+)/, $remainder);
    my (@words, @ws);
    foreach my $tok (@all_split) {
        if ($tok =~ m/^\s+$/) {
            push @ws, $tok
        } else {
            push @words, $tok
        }
    }
    return ($leading_ws, \@words, \@ws);
}


sub reassemble_with_whitespace {
    my ($leading, $words, $ws) = @_;

    # interleave the two arrays. Words always come first, because
    # any leading space is in $leading.
    # http://www.perlmonks.org/?node_id=53605

    # if things are different sizes we'll end up with some undefs,
    # so grep them out.
    my @ret = grep { defined } map { $words->[$_], $ws->[$_] }
      0 .. ($#$words > $#$ws ? $#$words : $#$ws);
    # and convert back to a string.
    return $leading . join('', @ret);
}

sub buttify_string($_) {
    my $self = shift;
    # glom a string from $_ if we didn't get one passed.
    my $str = (@_ ? $_[0] : $_);
    chomp($str);

    # FIX for http://code.google.com/p/buttbot/issues/detail?id=7
    my ($leading, $words, $whitespace)
      = split_preserving_whitespace($str);

    my @butted_words = $self->buttify(@$words);

    return reassemble_with_whitespace($leading, \@butted_words, $whitespace);
}

sub buttify {
    my ($self, @words) = @_;
	my $how_many_butts = int(@words * $self->{replace_freq}) + 1;
    my $debug = $self->{debug};

    $self->{_words} = \@words;
	# sort indices by word length
	my @word_idxs_len_sorted = do {
		my $c;

		map  { $_->[0] }
        sort { $b->[1] <=> $a->[1] }
        map  { [$c++ , length($_) ] } @words;
	};

	# remove stop words
	@word_idxs_len_sorted = grep {
		my $word = $words[$_];

		my $is_word = $word !~ /^[\d\W+]+$/;
		my $is_stop = $self->is_stop_word($word);
        my $is_meme = $self->is_meme($word);

		$is_word and not $is_stop and not $is_meme;
	} @word_idxs_len_sorted;

    $self->{_word_indices} = \@word_idxs_len_sorted;

    # bail out if we've got nothing left. This happens
    # when a string is comprised entirely of stop-words.
    unless (@word_idxs_len_sorted) {
        $self->log("Couldn't buttify ", join(' ', @words),
                   ": entirely stopwords");
        return @words;
    }

    # make sure we're not trying to butt too hard.
    if ($how_many_butts > @word_idxs_len_sorted) {
        $how_many_butts = scalar(@word_idxs_len_sorted);
    }

    $self->log("buttifying with $how_many_butts repetitions");
    my $words_butted = {};
    my @initial_weights = _sq_weight_indices(scalar @word_idxs_len_sorted);

    # Selecting words to butt works in the following way:

    #  * each (non-stop) word-index is assigned a weighting based on it's
    #    ordinal when sorted by (word) length. So, the longest word has weight =
    #    num_words ** 2, second longest is (num_words-1)**2, ...

    #  * A random distribution selects some index proportional to its weight.
    #  * The word at this index is butted.
    #  * The index is removed from consideration for subsequent buttings.

	for my $c (0 .. $how_many_butts-1) {
        my ($xx_n, $xx_p, $xx_x)
          = $self->_build_weightings_for_index(\@initial_weights, $words_butted);

        my $random_idx  = get_walker_rand($xx_n, $xx_p, $xx_x);
        my $idx_to_butt = $word_idxs_len_sorted[$random_idx];

        $self->log("Butting word idx: $idx_to_butt [",
                   $words[$idx_to_butt], "]");

		$words[$idx_to_butt]
          = $self->_buttsub($words[$idx_to_butt]);

        $words_butted->{$random_idx} = 1;
	}

	return @words;
}

sub _buttsub {
    my ($self, $word) = @_;

    my $meme = $self->{meme};

	# split off leading and trailing punctuation
	my ($lp, $actual_word, $rp) = $word =~ /^([^A-Za-z]*)(.*?)([^A-Za-z]*)$/;

	return $word unless $actual_word;

	my @points = (0, $self->{hyphenator}->hyphenate($actual_word));

	my $factor = 2;
	my $length = scalar @points;
	my $replace = $length - 1 - int(rand($length ** $factor) ** (1 / $factor));
	push @points, length($actual_word);

	my $l = $points[$replace];
	my $r = $points[$replace + 1] - $l;

	while (substr($actual_word, $l + $r, 1) eq 't') {
        $r++;
    }
	while ($l > 0 && substr($actual_word, $l - 1, 1) eq 'b') {
        $l--;
    }
	my $sub = substr($actual_word, $l, $r);
	my $butt = lc($meme);

	if ($sub eq uc $sub) {
		$butt = uc($meme);
	} elsif ($sub =~/^[A-Z]/) {
		$butt = ucfirst($meme);
	}

	substr($actual_word, $l, $r) = $butt;
	return $lp . $actual_word . $rp;
}

sub _build_weightings_for_index {
    my ($self, $initial_weights, $butted_indices) = @_;

    #$self->log("Word indices remaining: ", @indices);

    my $i = 0;
    $self->log(Dumper($butted_indices));
    $self->log(Dumper($initial_weights));

    my @idx_weights = map {
        exists($butted_indices->{$i++})?0:$_
    } @$initial_weights;

    my $str;
    $i = 0;
    for (@{$self->{_word_indices}}) {
        $str .= "\tIndex: $_: " . $self->{_words}->[$_]
          . " ,weight=" . $idx_weights[$i++] . "\n";
    }
    $self->log("index weightings:\n" . $str);

    my ($n, $p, $x) = setup_walker_rand(\@idx_weights);
    return ($n, $p, $x)
}

sub _sq_weight_indices {
    my $max = shift;
    return map { $max-- ** 2 } (0..$max-1);
}


# stealed frm http://code.activestate.com/recipes/576564/
# and http://prxq.wordpress.com/2006/04/17/the-alias-method/
# Copyright someone maybe somewhere?
sub setup_walker_rand {
    my ($weight_ref) = @_;

    my @weights = @$weight_ref;
    my $n = scalar @weights;
    my @in_x = (-1) x $n;
    my $sum_w = 0;
    $sum_w += $_ for @weights;

    # normalise weights to have an average value of 1.
    @weights = map { $_ * $n / $sum_w } @weights;

    my (@short, @long);
    my $i = 0;

    # split into long and short groups (excluding those which == 1)
    for my $p (@weights) {
        if ($p < 1) {
            push @short, $i;
        } elsif ($p > 1) {
            push @long, $i;
        }
        $i++;
    }

    # build alias map by combining short and long elements.
    while (scalar @short and scalar @long) {
        my $j = pop @short;
        my $k = $long[-1];

        $in_x[$j] = $k;
        $weights[$k] -= (1 - $weights[$j]);

        if ($weights[$k] < 1) {
            push @short, $k;
            pop @long;
        }
#        printf("test: j=%d k=%d pk=%.2f\n", $j, $k, $prob[$k]);
    }
    return ($n, \@weights, \@in_x)
}

sub get_walker_rand {
    my ($n, $prob, $in_x) = @_;
    my ($u, $j);
    $u = random_uniform(1,0,1);
    $j = random_uniform_integer(1, 0, $n-1);
    return ($u <= $prob->[$j]) ? $j : $in_x->[$j];
}

sub log {
    my ($self, @msg) = @_;
    if ($self->{debug}) {
        print STDERR join(" ", @msg) . $/;
    }
}

1;
