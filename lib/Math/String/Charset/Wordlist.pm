#!/usr/bin/perl -w

#############################################################################
# Math/String/Charset/Wordlist.pm -- a dictionary charset for Math/String
#
# Copyright (C) 2003 by Tels. All rights reserved.
#############################################################################

package Math::String::Charset::Wordlist;
use base Math::String::Charset;

use vars qw($VERSION);
$VERSION = 0.01;	# Current version of this package
require  5.005;		# requires this Perl version or later

use strict;
use Math::BigInt;
use Tie::File;
use Fcntl 'O_RDONLY';

use vars qw/$die_on_error/;
$die_on_error = 1;              # set to 0 to not die

# following hash values are used:
# _clen  : length of one character (all chars must have same len unless sep)
# _ones  : list of one-character strings (cross of _end and _start)
# _start : contains array of all valid start characters
# _end   : contains hash (for easier lookup) of all valid end characters
# _order : = 1
# _type  : = 2
# _error : error message or ""
# _count : array of count of different strings with length x
# _sum   : array of starting number for strings with length x
#          _sum[x] = _sum[x-1]+_count[x-1]
# _cnt   : number of elements in _count and _sum (as well as in _scnt & _ssum)
# _cnum  : number of characters in _ones as BigInt (for speed)
# _minlen: minimum string length (anything shorter is invalid), default -inf
# _maxlen: maximum string length (anything longer is invalid), default +inf

# simple ones:
# _sep  : separator string (undef for none)
# _map  : mapping character to number

# _list : tied array containing the exteral wordlist
# _file : path/filename of _list
# _len  : count of records in _list

#############################################################################
# private, initialize self 

sub _strict_check
  {
  # a per class check, to be overwritten by subclasses
  my ($self,$value) = @_;

  $self->{_type} ||= 2;
  $self->{_order} ||= 1;

  my $class = ref($self);
  return $self->{_error} = "Wrong type '$self->{_type}' for $class"
    if $self->{_type} != 2;
  return $self->{_error} = "Wrong order'$self->{_order}' for $class"
    if $self->{_order} != 1;
  foreach my $key (keys %$value)
    {
    return $self->{_error} = "Illegal parameter '$key' for $class"
      if $key !~ /^(start|order|type|minlen|maxlen|file|end)$/;
    }
  }

sub _initialize
  {
  my ($self,$value) = @_;

  # sep char not used yet
  $self->{_sep} = $value->{sep};		# separator char

  $self->{_file} = $value->{file} || '';	# filename and path
 
  if (!-f $self->{_file} || !-e $self->{_file})
    {
    return $self->{_error} = "Cannot open dictionary '$self->{_file}': $!\n";
    }
  my @words;
  # restrict cache size because our words are expected to be small and the
  # cache overhead is likely to be great
  tie @words, 'Tie::File', $self->{_file}, mode => O_RDONLY, memory => 50000;
  $self->{_list} = \@words;
  
  return $self->{_error} = 
   "Couldn't tie dictionary file to array"
    if ref($self->{_list} ne 'Tie::File');

  # don't cache the _len yet, because this is costly
 
  # only one "char" for now
  $self->{_minlen} = 0;
  $self->{_maxlen} = 1;

  return $self->{_error} = 
   "Minlen ($self->{_minlen} must be <= than maxlen ($self->{_maxlen})"
    if ($self->{_minlen} >= $self->{_maxlen});
  $self;
  }

sub offset
  {
  # return the offset of the n'th word into the file
  my ($self,$n) = @_;

  my $class = tied(@{$self->{_list}});
  $class->offset($n);
  }

sub is_valid
  {
  # check wether a string conforms to the given charset sets
  my $self = shift;
  my $str = shift;

  # print "$str\n";
  return 0 if !defined $str;
  return 1 if $str eq '' && $self->{_minlen} <= 0;

  my $int = Math::BigInt->bzero();
  my @chars;
  if (defined $self->{_sep})
    {
    @chars = split /$self->{_sep}/,$str;
    shift @chars if $chars[0] eq '';
    pop @chars if $chars[-1] eq $self->{_sep};
    }
  else
    {
    @chars = $str;
    # not supported yet
    #my $i = 0; my $len = CORE::length($str); my $clen = $self->{_clen};
    #while ($i < $len)
    #  {
    #  push @chars, substr($str,$i,$clen); $i += $clen;
    #  }
    }
  # length okay?
  return 0 if scalar @chars < $self->{_minlen};
  return 0 if scalar @chars > $self->{_maxlen};

  # further checks for strings longer than 1
  foreach my $c (@chars)
    {
    return 0 if !defined $self->str2num($c);
    }
  # all tests passed
  1;
  }

sub minlen
  {
  my $self = shift;

  $self->{_minlen};
  }

sub maxlen
  {
  my $self = shift;

  $self->{_maxlen};
  }

sub start
  {
  # this returns all the starting characters in a list, or in case of a simple
  # charset, simple the charset
  # in scalar context, returns length of starting set, for simple charsets this
  # equals the length
  my $self = shift;

  return wantarray ? @{$self->{_start}} : scalar @{$self->{_start}};
  }
      
sub end
  {
  # this returns all the end characters in a list, or in case of a simple
  # charset, simple the charset
  # in scalar context, returns length of end set, for simple charsets this
  # equals the length
  my $self = shift;

  return wantarray ? sort keys %{$self->{_end}} : scalar keys %{$self->{_end}};
  }

sub ones
  {
  # this returns all the one-char strings (in scalar context the count of them)
  my $self = shift;

  return wantarray ? @{$self->{_ones}} : scalar @{$self->{_ones}};
  }

sub count
  {
  my $self = shift;

  # XXX todo: only strings one "char" long are valid for now
  $self->{_len} = scalar @{$self->{_list}} if !defined $self->{_len};
  $self->{_len};
  }

sub length
  {
  my $self = shift;

  $self->{_len} = scalar @{$self->{_list}} if !defined $self->{_len};
  $self->{_len};
  }

sub num2str
  {
  # convert Math::BigInt/Math::String to string
  # in list context, return (string,stringlen) 
  my $self = shift;
  my $x = shift;

  $x = new Math::BigInt($x) unless ref $x; 
  return undef if ($x->sign() !~ /^[+-]$/);
  my $l = '';			# $x == 0 as default
  my $int = $x->numify();
  if ($int > 0)
    {
    # Tie::File makes this _very_ easy
    $l = $self->{_list}[$int - 1];
    }
  wantarray ? ($l,1) : $l;
  }

sub str2num
  {
  # convert Math::String to Math::BigInt
  my $self = shift;
  my $str = shift;

  return Math::BigInt->bzero() if $str eq '';

  $self->{_searches}++;
  # do a binary search for the string in the array of strings
  my $left = 0; my $right = $self->count() - 1;
  my $middle;
  my $LIST = $self->{_list};
  while ($right - $left > 1)
    {
    $self->{_search_steps}++;
    my $leftstr = $LIST->[$left];
    return Math::BigInt->new($left+1) if $leftstr eq $str;
    my $rightstr = $LIST->[$right];
    return Math::BigInt->new($right+1) if $rightstr eq $str;

    # simple middle median computing
    $middle = int(($left + $right) / 2);

    if (CORE::length($leftstr) == CORE::length($rightstr))
      {
      # advanced middle computing:
      my $ll = ord(substr($leftstr,0,1));
      my $rr = ord(substr($rightstr,0,1));
      if ($rr - $ll > 1)
        {
        my $mm = ord(substr($str,0,1));
        $mm ++ if $mm == $ll;
        $mm -- if $mm == $rr;
        #print "ll $ll mm $mm rr $rr\n";
        # now make $middle so that :
        # $mm - $ll      $middle - $left    
        # ----------- = ----------------- =>
        # $rr - $ll      $right - $left 
        #
        #         ($mm - $ll) * ($right - $left)
        # $left + ----------------------------
        #            $rr - $ll
        $middle = $left +
          int(($mm - $ll) * ($right - $left) / ($rr - $ll));
        $middle ++ if $middle == $left;
        $middle -- if $middle == $right;
        }
      }

    my $middlestr = $LIST->[$middle];
    return Math::BigInt->new($middle+1) if $middlestr eq $str;
    # so it is neither left, nor right nor middle, so see in which half it
    # should be
    my $cmp = CORE::length($middlestr) <=> CORE::length ($str) 
      || $middlestr cmp $str;
    # cmp != 0 here
    if ($cmp < 0)
      {
      $left = $middle;
      }
    else
      {
      $right = $middle;
      }
    }
  return if $right - $left == 1;        # not found
  Math::BigInt->new($middle+1);
  }

sub char
  {
  # return nth char from charset
  my $self = shift;
  my $char = shift || 0;
 
  $self->{_list}[$char];
  }

sub first
  {
  my $self = shift;
  my $count = abs(shift || 0);

  return if $count < $self->{_minlen};
  return if defined $self->{_maxlen} && $count > $self->{_maxlen};
  return '' if $count == 0;
  
  my $str = $self->{_list}->[0];

  return $str if $count == 1;
 
  my $s = $self->{_sep} || '';
  my $res = '';
  for (my $i = 0; $i < $count; $i++)
    { 
    $res .= $s . $str;
    }
  $s = quotemeta($s);
  $res =~ s/^$s// if $s ne '';		# remove first sep
  $res;
  }

sub last
  {
  my $self = shift;
  my $count = abs(shift || 0);

  return if $count < $self->{_minlen};
  return if defined $self->{_maxlen} && $count > $self->{_maxlen};
  return '' if $count == 0;

  my $str = $self->{_list}->[-1];
  return $str if $count == 1;
 
  my $res = '';
  my $s = $self->{_sep} || '';
  for (my $i = 1; $i <= $count; $i++)
    {
    $res .= $s . $str;
    }
  $s = quotemeta($s);
  $res =~ s/^$s// if $s ne '';		# remove first sep
  $res;
  }

sub next
  {
  my ($self,$str) = @_;

# for timing disable it here:
#  $str->{_cache}->{str} = undef; return;
#  return if !defined $str->{_cache}->{str};
  if ($str->{_cache}->{str} eq '')				# 0 => 1
    {
    my $min = $self->{_minlen}; $min = 1 if $min <= 0;
    $str->{_cache}->{str} = $self->first($min);
    return;
    }

  # only the rightmost digit is adjusted. If this overflows, we simple
  # invalidate the cache. The time saved by updating the cache would be to
  # small to be of use, especially since updating the cache takes more time
  # then. Also, if the cached isn't used later, we would have spent the
  # update-time in vain.

  # extract the current value
  $str->{_cache}->{str} = $self->{_list}->[$str->numify()-1];
  #$str->{_cache} = undef;
  }

sub prev
  {
  my ($self,$str) = @_;

  if ($str->{_cache}->{str} eq '')				# 0 => -1
    {
    my $min = $self->{_minlen}; $min = -1 if $min >= 0;
    $str->{_cache}->{str} = $self->first($min);
    return;
    }

  # extract the current value
  $str->{_cache}->{str} = $self->{_list}->[$str->numify()-1];
  #$str->{_cache} = undef;
  }

__END__

#############################################################################

=head1 NAME

Math::String::Charset::Wordlist - A dictionary charset for Math::String

=head1 SYNOPSIS

    use Math::String::Charset::Wordlist;

    my $x = Math::String::Charset::Wordlist->new ( {
	file => 'path/dictionary.lst' } );

=head1 REQUIRES

perl5.005, Exporter, Fcntl, Tie::File, Math::BigInt, Math::String::Charset

=head1 EXPORTS

Exports nothing.

=head1 DESCRIPTION

This module lets you create an charset object, which is used to construct
Math::String objects. 

This object maps an external wordlist (aka a dictionary file where one
line contains one word) to a simple charset, e.g. each word is one character
in the charset.

=head1 ERORRS

Upon error, the field C<_error> stores the error message, then die() is called
with this message. If you do not want the program to die (f.i. to catch the
errors), then use the following:

	use Math::String::Charset::Wordlist;

	$Math::String::Charset::Wordlist::die_on_error = 0;

	$a = new Math::String::Charset::Wordlist ();	# error, empty set!
	print $a->error(),"\n";

=head1 INTERNAL DETAILS

This object caches certain calculation results (f.i. which word is stored
at which offset in the file etc), thus greatly speeding up sequentiell
Math::String conversations from string to number, and vice versa.

=head1 METHODS

=head2 B<new()>

            new();

Create a new Math::Charset::Wordlist object. 

The constructor takes a HASH reference. The following keys can be used:

	minlen		Minimum string length, -inf if not defined
	maxlen		Maximum string length, +inf if not defined
	file		path/filename of wordlist file
	sep		separator character, none if undef

The resulting charset will always be of order 0, type 3.

=over 2

=item minlen

Optional minimum string length. Any string shorter than this will be invalid.
Must be shorter than a (possible defined) maxlen. If not given is set to -inf.
Note that the minlen might be adjusted to a greater number, if it is set to 1
or greater, but there are not valid strings with 2,3 etc. In this case the
minlen will be set to the first non-empty class of the charset.

=item maxlen

Optional maximum string length. Any string longer than this will be invalid.
Must be longer than a (possible defined) minlen. If not given is set to +inf.

=back

=head2 B<minlen()>

	$charset->minlen();

Return minimum string length.

=head2 B<maxlen()>

	$charset->maxlen();

Return maximum string length.

=head2 B<length()>

	$charset->length();

Return the number of items in the charset, for higher order charsets the
number of valid 1-character long strings. Shortcut for 
C<< $charset->class(1) >>.
  
=head2 B<count()>

Returns the count of all possible strings described by the charset as a
positive BigInt. Returns 'inf' if no maxlen is defined, because there should
be no upper bound on how many strings are possible.

If maxlen is defined, forces a calculation of all possible L<class()> values
and may therefore be very slow on the first call, it also caches possible
lot's of values if maxlen is very high.

=head2 B<class()>

	$charset->class($order);

Return the number of items in a class.

	print $charset->class(5);	# how many strings with length 5?

=head2 B<char()>

	$charset->char($nr);

Returns the character number $nr from the set, or undef.

	print $charset->char(0);	# first char
	print $charset->char(1);	# second char
	print $charset->char(-1);	# last one

=head2 B<lowest()>

	$charset->lowest($length);

Return the number of the first string of length $length. This is equivalent
to (but much faster):

	$str = $charset->first($length);
	$number = $charset->str2num($str);

=head2 B<highest()>

	$charset->highest($length);

Return the number of the last string of length $length. This is equivalent
to (but much faster):

	$str = $charset->first($length+1);
	$number = $charset->str2num($str);
        $number--;

=head2 B<order()>

	$order = $charset->order();

Return the order of the charset: is always 1 for grouped charsets.
See also L<type>.

=head2 B<type()>

	$type = $charset->type();

Return the type of the charset: is always 1 for grouped charsets. 
See also L<order>.

=head2 B<charlen()>

	$character_length = $charset->charlen();

Return the length of one character in the set. 1 or greater. All charsets
used in a grouped charset must have the same length, unless you specify a 
seperator char.

=head2 B<seperator()>

	$sep = $charset->seperator();

Returns the separator string, or undefined if none is used.

=head2 B<chars()>

	$chars = $charset->chars( $bigint );

Returns the number of characters that the string would have, when you would
convert $bigint (Math::BigInt or Math::String object) back to a string.
This is much faster than doing

	$chars = length ("$math_string");

since it does not need to actually construct the string.

=head2 B<first()>

	$charset->first( $length );

Return the first string with a length of $length, according to the charset.
See C<lowest()> for the corrospending number.

=head2 B<last()>

	$charset->last( $length );

Return the last string with a length of $length, according to the charset.
See C<highest()> for the corrospending number.

=head2 B<is_valid()>

	$charset->is_valid();

Check wether a string conforms to the charset set or not.

=head2 B<error()>

	$charset->error();

Returns "" for no error or an error message that occured if construction of 
the charset failed. Set C<$Math::String::Charset::die_on_error> to C<0> to
get the error message, otherwise the program will die.

=head2 B<start()>

	$charset->start();

In list context, returns a list of all characters in the start set, that is
the ones used at the first string position.
In scalar context returns the lenght of the B<start> set.

Think of the start set as the set of all characters that can start a string
with one or more characters. The set for one character strings is called
B<ones> and you can access if via C<$charset->ones()>.

=head2 B<end()>

	$charset->end();

In list context, returns a list of all characters in the end set, aka all
characters a string can end with. 
In scalar context returns the lenght of the B<end> set.

=head2 B<ones()>

	$charset->ones();

In list context, returns a list of all strings consisting of one character.
In scalar context returns the lenght of the B<ones> set.

This list is the cross of B<start> and B<end>.

Think of a string of only one character as if it starts with and ends in this
character at the same time.

The order of the chars in C<ones> is the same ordering as in C<start>.

=head2 B<prev()>

	$string = Math::String->new( );
	$charset->prev($string);

Give the charset and a string, calculates the previous string in the sequence.
This is faster than decrementing the number of the string and converting the
new number to a string. This routine is mainly used internally by Math::String
and updates the cache of the given Math::String.

=head2 B<next()>

	$string = Math::String->new( );
	$charset->next($string);

Give the charset and a string, calculates the next string in the sequence.
This is faster than incrementing the number of the string and converting the
new number to a string. This routine is mainly used internally by Math::String
and updates the cache of the given Math::String.

=head1 EXAMPLES

	use Math::String;
	use Math::String::Charset::Wordlist;

	my $cs = 
	  Math::String::Charset::Wordlist->new( { file => 'big.sorted' } );
	my $x = 
	  Math::String->new('',$cs)->binc();	# $x is now the first word

	while ($x < Math::BigInt->new(10))	# Math::BigInt->new() necc.!
	  {
	  # print the first 10 words
	  print $x++,"\n";
	  }

=head1 BUGS

None doscovered yet.

=head1 AUTHOR

If you use this module in one of your projects, then please email me. I want
to hear about how my code helps you ;)

This module is (C) Copyright by Tels http://bloodgate.com 2003.

=cut

