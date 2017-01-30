#!/usr/bin/perl -w

#############################################################################
# Math/String/Charset.pm -- package which defines a charset for Math/String
#
# Copyright (C) 1999-2001 by Tels. All rights reserved.
#############################################################################

# todo: tri-grams etc
#       store counts for different end-chars at the max elemt of _count?
#       if we later need to calculate further, we could pick up there and need
#       not to re-calculate the lower numbers

package Math::String::Charset;
use base Exporter;
@EXPORT_OK = qw/SIMPLE/;

use vars qw($VERSION);
$VERSION = 1.09;	# Current version of this package
require  5.005;		# requires this Perl version or later

use strict;
use Math::BigInt;
my $class = "Math::String::Charset";

use vars qw/$die_on_error/; 
$die_on_error = 1;		# set to 0 to not die

use constant SIMPLE => 1;

# following hash values are used:
# _clen : length of one character (all chars must have same length unless sep)
# _start: contains array of all valid start characters
# _ones : list of one-character strings (cross of _end and _start)
# _end  : contains hash (for easier lookup) of all valid end characters
# _order: 1,2,3.. etc, type/class of charset
# _error: error message or ""
# _count: array of count of different strings with length x
# _sum  : array of starting number for strings with length x
#         _sum[x] = _sum[x-1]+_count[x-1]
# _cnt  : number of elements in _count and _sum (as well as in _scnt and _ssum)
# _cnum : number of characters in _ones as BigInt (for speed)

# simple ones:
# _sep  : separator string (undef for none)
# _map  : mapping character to number

# higher orders:
# _bi   : hash with refs to array of bi-grams
# _bmap : hash with refs to hash of bi-grams
# _scnt : array of hashes, count of strings starting with this character
# _ssum : array of hashes, first number of string starting with this character

sub new
  {
  my $class = shift;
  $class = ref($class) || $class;
  my $self = {};
  bless $self, $class;
  my $value;
  if (!ref($_[0]))
    {
    $value = [ @_ ];
    }
  else
    {
    $value = shift;
    }
  if (ref($value) !~ /^(ARRAY|HASH)$/)
    {
    # got an object, so make copy
    foreach my $k (keys %$value)
      {
      if (ref($value->{$k}) eq 'ARRAY')
        {
        $self->{$k} = [ @{$value->{$k}} ];
        }
      elsif (ref($value->{$k}) eq 'HASH')
        {
        foreach my $j (keys %{$value->{k}})
          {
          $self->{$k}->{$j} = $value->{$k}->{$j};
          }
        }
      else
        {
        $self->{$k} = $value->{$k};
        }
      }
    return $self; 
    }
  $self->_initialize($value);
  return $self; 
  }

#############################################################################
# private, initialize self 

sub _initialize
  {
  # set yourself to the value represented by the given string
  my $self = shift;
  my $value = shift;

  $self->{_error} = ""; 			# no error
  $self->{_count} = [ ];

  # convert array ref to hash	
  $value = { start => $value } if (ref($value) eq 'ARRAY');
  $self->{_order} = $value->{order} || SIMPLE; 		# simple by default
  $self->{_sep} = $value->{sep};			# sep char or undef
  $self->{_error} = "Field 'sep' must not be empty" 
    if (defined $self->{_sep} && $self->{_sep} eq '');

  $self->{_start} = [ @{$value->{start}} ];		# make copy
  $self->{_clen} = CORE::length($self->{_start}->[0]);	# from first take clen
  my $bi;
  $self->{_order} = 2 if defined $value->{bi} || defined $value->{end};
  if ($self->{_order} == 1)
    {
    $self->{_ones} = $self->{_start};
    foreach (@{$self->{_start}}) { $self->{_end}->{$_} = 1; }
    }
  else
    {
    my $end = {}; 			# we make array later on
    # add the user-specified end set
    my $start = $value->{end};
    $bi = $value->{bi} || {};
    $self->{_error} = "Field 'bi' must be hash ref" if ref($bi) ne 'HASH';
    $self->{_order} = 2;
    # if no end set is defined, add all followers as default
    if (defined $start)
      {
      foreach (@$start) { $end->{$_} = 1; }
      }
    else
      {
      foreach my $c (keys %$bi)
        {
        foreach my $f (@{$bi->{$c}})
          {
          $end->{$f} = 1;
          }
        }
      }
    # make copy
    foreach my $c (keys %$bi)
      {
      $self->{_bi}->{$c} = [ @{$bi->{$c}} ]; 	# make copy 
      }
    # add empty array for chars with no followers
    $bi = $self->{_bi};
    foreach my $c (keys %$bi)
      {
      $end->{$c} = 1 if @{$self->{_bi}->{$c}} == 0;
      foreach my $f (@{$bi->{$c}})
        {
        $self->{_bi}->{$f} = [] if !defined $self->{_bi}->{$f};
        $end->{$f} = 1 if @{$self->{_bi}->{$f}} == 0;
        $self->{_error} = "Illegal char '$f', length not $self->{_clen}"
          if length($f) != $self->{_clen};
        }
      }
    #print "start :";
    #foreach my $c (@{$self->{_start}})
    ##    {
    #    print "$c ";
    #    }
    #  print "\n";
    #  print "charset:\n";
    #  foreach my $c (keys %$bi)
    #    {
    #    print "$c => [";
    #    foreach my $f (@{$bi->{$c}})
    #      {
    #      print "'$f', ";
    #      }
    #    print "]\n";
    #    }
    #  print "end :";
    #  foreach my $c (keys %$end)
    #    {
    #    print "$c ";
    #    }
    #  print "\n";
 
    $self->{_end} = $end;
    # build _ones list
    $self->{_ones} = [];
    foreach (@{$self->{_start}})
      {
      push @{$self->{_ones}}, $_ if exists $end->{$_};
      }
    } # end for higher order
  # some tests for validity
  if (!defined $self->{_sep})
    {
    foreach (@{$self->{_start}})
      {
      $self->{_error} = "Illegal char '$_', length not $self->{_clen}"
          if length($_) != $self->{_clen};
      }
    }
  # initialize array of counts for len of 0..1
  $self->{_count}->[0] = 0;						# 0
  $self->{_count}->[1] = Math::BigInt->new (scalar @{$self->{_ones}});	# 1
  $self->{_cnt} = 1;	# cache size
  if ($self->{_order} != SIMPLE)
    {
    # initialize array of counts for len of 2
    my $end = $self->{_end};
    my $count = Math::BigInt::bzero();
    foreach my $c (keys %$bi)
      {
      $count += scalar @{$bi->{$c}} if exists $end->{$c};
      }
    $self->{_count}->[2] = $count;					# 2
    $self->{_cnt}++;	# adjust cache size
    }
  # init _sum array
  $self->{_sum}->[0] = 0;
  $self->{_sum}->[1] = 1;
  $self->{_sum}->[2] = $self->{_count}->[1] + 1;
  # from start, make mapping name => number
  my $i = 1;
  foreach (@{$self->{_ones}})
    {
    $self->{_map}->{$_} = $i++;
    }
  if ($self->{_order} != SIMPLE)
    {
    # create mapping for is_valid
    foreach my $c (keys %{$self->{_bi}})	# for all chars
      {
      foreach my $cf (@{$self->{_bi}->{$c}})	# for all followers
        {
        $self->{_bmap}->{$c}->{$cf} = 1;	# make hash for easier lookup
        }
      }
    
    # init _scnt and _ssum arrays/hashes ([0] not used in both)
    $self->{_scnt}->[1] = {};
    $self->{_ssum}->[1] = {};
    foreach my $c (keys %{$self->{_map}})	# it's nearly the same
      {
      $self->{_ssum}->[1]->{$c} = $self->{_map}->{$c} - 1;
      }
    my $last = Math::BigInt::bzero();	
    foreach my $c (@{$self->{_start}})
      {
      $self->{_scnt}->[1]->{$c} = 1		# exactly one for each char
	if exists $self->{_end}->{$c};		# but not for invalid
      my $cnt = 0;				# number of followers
      foreach my $cf (@{$bi->{$c}})		# for each follower
        {
	# only if 2-character-long string could end in this char
        $cnt ++ if exists $self->{_end}->{$cf};	
        }
      $self->{_scnt}->[2]->{$c} = $cnt;		# store
      $self->{_ssum}->[2]->{$c} = $last;	# store sum up to here
      $last += $cnt;				# next one is summed up
      }
    $self->{_count}->[2] = $last;		# all in that class
    $self->{_cnt} = 2;				# cache size for bi is one more
    }
  $self->{_error} = "Empty charset!" if @{$self->{_ones}} == 0;
  $self->{_cnum} = Math::BigInt->new( scalar @{$self->{_ones}} );
  die ($self->{_error}) if $die_on_error && $self->{_error} ne '';
  return $self;
  }

sub error
  {
  my $self = shift;
 
  return $self->{_error};
  }

sub order
  {
  # return charset's type/order/class
  my $self = shift;
  return $self->{_order};
  }

sub charlen
  {
  # return charset's length of one character
  my $self = shift;
  return $self->{_clen};
  }

sub length
  {
  # return number of characters in charset
  my $self = shift;

  return scalar @{$self->{_ones}};
  }

sub _calc
  {
  # given count of len 1..x, calculate count for y (y > x) and all between
  # x and y
  # currently re-calcs from 2 on, we could save the state and only calculate
  # the missing counts.

  my $self = shift;
  my $max = shift || 1; $max = 1 if $max < 1;
  return if $max <= $self->{_cnt};

  if ($self->{_order} == SIMPLE)
    {
    my $i = $self->{_cnt}; 		# last defined element
    my $last = $self->{_count}->[$i];
    my $size = Math::BigInt->new ( scalar @{$self->{_ones}} );
    while ($i <= $max)
      {
      $last = $last * $size;
      $self->{_count}->[$i+1] = $last; 
      $self->{_sum}->[$i+1] = $self->{_sum}->[$i] + $self->{_count}->[$i];
      $i++;
      }
    $self->{_cnt} = $i-1;		# store new cache size
    return;
    }

#  my ($counts,$org_counts);
# map to hash
#  my $end = $self->{_end};
#  %$counts = map { $_, $end->{$_} } keys %$end; 	# make copy

  my ($c,$cf,$cnt,$last);	
  my $i = $self->{_cnt}+1;		# start with next undefined level
  while ($i <= $max)
    {
    # take current level, calculate all possible ending characters
    # and count them (e.g. 2 times 'b', 2 times 'c' and 3 times 'a')
    # each of the ending chars has a number of possible bi-grams. For the next
    # length, we must add the count of the ending char to each of the possible
    # bi-grams. After this, we get the new count for all new ending chars.
 #   %$org_counts = map { $_, $counts->{$_} } keys %$counts; 	# make copy
 #   $counts = {};						# init to 0
 #   $cnt = Math::BigInt::bzero();
 #   # for each of the ending chars
 #   foreach my $char (keys %$org_counts)
 #     {
 #     # and for each of it's bigrams
 #     $c = $org_counts->{$char};			# speed up
 #     foreach my $ec ( @{$self->{_bi}->{$char}})
 #       {
 #       # add to the new ending char the number of possibilities
 #       $counts->{$ec} += $c;
 #       }
 #     # now sum them up by multiplying bi-grams times org_char count
 #     $cnt += @{$self->{_bi}->{$char}} * $org_counts->{$char};
 #     }
 #   $self->{_count}->[$i] = $cnt;	# store this level
 #   #print "$i => $self->{_count}->[$i]\n";

    #########################################################################
    # for each starting char, add together how many strings each follower
    # starts in level-1
    $last = Math::BigInt->bzero();		# set to 0
    foreach $c (@{$self->{_start}})
      {
      $cnt = Math::BigInt->bzero();		# number of followers
      foreach $cf (@{$self->{_bi}->{$c}})	# for each follower
        {
        $cnt += $self->{_scnt}->[$i-1]->{$cf};	# add count in level-1
        }
      $self->{_scnt}->[$i]->{$c} = $cnt;	# and store it
      $self->{_ssum}->[$i]->{$c} = $last;	# store sum up to here
      $last += $cnt;				# next one is summed up
      }
    $self->{_count}->[$i] = $last;		# sum of all strings
    $self->{_sum}->[$i] = $self->{_count}->[$i-1] + $self->{_sum}->[$i-1];
    $i++;
    }
  $self->{_cnt} = $i-1;				# store new cache size
  }

sub class
  {
  # return number of all combinations with a certain length
  my $self = shift;
  my $len = abs(int(shift || 1));
  
  # not known yet, so calculate and cache
  $self->_calc($len) if $self->{_cnt} < $len;
  return $self->{_count}->[$len];				
  }

sub lowest
  {
  # return number of first string with $length characters
  # equivalent to $charset->first($length)->num2str();
  my $self = shift;
  my $len = abs(int(shift || 1));
  
  # not known yet, so calculate and cache
  $self->_calc($len) if $self->{_cnt} < $len;
  return $self->{_sum}->[$len];
  }

sub highest
  {
  # return number of first string with $length characters
  # equivalent to $charset->first($length)->num2str();
  my $self = shift;
  my $len = abs(int(shift || 1));
  
  $len++;
  # not known yet, so calculate and cache
  $self->_calc($len) if $self->{_cnt} < $len;
  return $self->{_sum}->[$len]-1;
  }

sub is_valid
  {
  # check wether a string conforms to the given charset set
  my $self = shift;
  my $str = shift;

  return if !defined $str;
  return 1 if $str eq '';

  my $int = Math::BigInt::bzero();
  my @chars;
  if (defined $self->{_sep})
    {
    @chars = split /$self->{_sep}/,$str;
    shift @chars if $chars[0] eq '';
    pop @chars if $chars[-1] eq $self->{_sep};
    }
  else
    {
    my $i = 0; my $len = CORE::length($str); my $clen = $self->{_clen};
    while ($i < $len)
      {
      push @chars, substr($str,$i,$clen); $i += $clen;
      }
    }
  # valid start char?
  return unless exists $self->{_map}->{ $chars[0] };
  if ($self->{_order} == SIMPLE)
    {
    foreach (@chars)
      {
      return unless exists $self->{_map}->{$_};
      }
    return 1;
    }
  # check if conforms to bi-grams
  my $len = CORE::length ($str);
  return 1 if $len == 1;
  # further checks for strings longer than 1
  my $i = 1; # start at second char
  my $map = $self->{_bmap};
  while ($i < $len)
    {
    #print "is valid $i $chars[$i-1] $chars[$i]\n";
    return unless exists $map->{$chars[$i-1]}->{$chars[$i]};
    $i++;
    }
  return 1;
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

sub num2str
  {
  # convert Math::BigInt/Math::String to string 
  my $self = shift;
  my $x = shift;

  $x = new Math::BigInt($x) unless ref $x;  
  return undef if $x->sign() eq 'NaN';
  return '' if $x->is_zero();
  my $j = $self->{_cnum};			# nr of chars

  return $self->{_ones}->[$x-1] if $x <= $j;	# string len == 1

  my $digits = $self->chars($x);
  # now treat the string as it were a zero-padded string of length $digits

  my $es="";                    		# result
  if ($self->{_order} == SIMPLE)
    { 
    # copy input, make positive number, correct to $digits and cater for 0
    my $y = Math::BigInt->new($x); $y->babs(); 
    #print "fac $j y: $y new: ";
    $y -= $self->{_sum}->[$digits];
 
    #print "y: $y\n";
    my $mod = 0; my $s = $self->{_sep}; $s = '' if !defined $s;
    while (!$y->is_zero())
      {
      #print "bfore:  y/fac: $y / $j \n";
      ($y,$mod) = $y->bdiv($j);
      $es = $self->{_ones}->[$mod] . $s.$es;
      #print "after:  div: $y rem: $mod \n";
      $digits --;				# one digit done
      }
    # padd the remaining digits with the zero-symbol
    $es = ($self->{_ones}->[0].$s) x $digits . $es if ($digits > 0);
    $es =~ s/$s$//;				# strip last sep 'char'
    return $es;
    }
  return "num2str() for bi-grams not ready yet";
  }

sub str2num
  {
  # convert Math::String to Math::BigInt
  my $self = shift;
  my $str = shift;			# simple string

  my $int = Math::BigInt::bzero();
  my $i = CORE::length($str);

  return $int if $i == 0;
  my $map = $self->{_map};
  my $clen = $self->{_clen};		# len of one char
  return new Math::BigInt($map->{$str}) if $i == $clen;
  if ($self->{_order} == SIMPLE)
    {
    my $j = $self->{_cnum};		# nr of chars as BigInt
    my $mul = $int+1; 			# 1
    if (!defined $self->{_sep})
      {
      $i -= $clen;
      while ($i >= 0)
        {
        $int += $mul * $map->{substr($str,$i,$clen)};
        $mul *= $j;
        $i -= $clen;
        #print "s2n $int j: $j i: $i m: $mul c: ",
        #substr($str,$i+$clen,$clen),"\n";
        }
      }
    else
      {
      # with sep char
      my @chars = split /$self->{_sep}/, $str;
      shift @chars if $chars[0] eq '';			# strip leading sep
      #pop @chars if $chars[-1] eq $self->{_sep};	# strip trailing sep
      foreach (reverse @chars)	
        {
        $int += $mul * $map->{$_};
        $mul *= $j;
        }
      }
    }
  else
    {
    if (!defined $self->{_sep})
      {
      my $class = $i / $clen;
      $self->_calc($class) if $class > $self->{_cnt};	# not yet cached?
      $int = $self->{_sum}->[$class];			# base number
      print "base $int class $class\n";
      $i = $clen; $class--; 
      print "start with pos $i, class $class\n";
      while ($class > 0)
        {
        $int += $self->{_ssum}->[$class]->{substr($str,$i,$clen)};
        print "$i $class $int ",substr($str,$i,$clen)," ",
         $self->{_ssum}->[$class]->{substr($str,$i,$clen)},"\n";
        $class --;
        $i += $clen;
        #print "s2n $int j: $j i: $i m: $mul c: ",
        #substr($str,$i+$clen,$clen),"\n";
        }
      print "$int\n";
      }
    else
      {
      # sep char
      my @chars = split /$self->{_sep}/, $str;
      shift @chars if $chars[0] eq '';			# strip leading sep
      foreach (@chars)
        {
        $int += $self->{_ssum}->[$class]->{$_};
        $class --;
        print "$class $int\n";
        }
      }
    }
  return $int;
  }

sub char
  {
  # return nth char from charset
  my $self = shift;
  my $char = shift || 0;
 
  return undef if $char > scalar @{$self->{_ones}}; # dont create spurios elems
  return $self->{_ones}->[$char];
  }

sub chars
  {
  # return number of characters in output string
  my $self = shift;
  my $x = shift;

  return 0 if $x->is_zero();
  return 0 if $x->is_nan();

  my $i = 1;
  if ($self->{_order} == SIMPLE)
    {
    my $y = Math::BigInt->new($x); $y->babs();
    while ($y >= $self->{_sum}->[$i])
      {
      #print "cnt: $self->{_cnt} for $i ";
      $self->_calc($i) if $self->{_cnt} < $i;
      #print "sum: $self->{_sum}->[$i]\n";
      $i++;
      }
    $i--;	# correct for ++
    }
  else
    {
    # not done yet
    }
  return $i;
  }                  

sub first
  {
  my $self = shift;
  my $count = shift || return '';

  my $f = '';
  if ($self->{_order} == SIMPLE)
    {
    $f = $self->{_ones}->[0] x $count;
    }
  else
    {
    }
  return $f;
  }

sub last
  {
  my $self = shift;
  my $count = shift || return '';

  my $f = '';
  if ($self->{_order} == SIMPLE)
    {
    $f = $self->{_ones}->[-1] x $count;
    }
  else
    {
    }
  return $f;
  }

sub next
  {
  my $self = shift;
  my $str = shift;

  # for higher orders not ready yet
  if ($self->{_order} != SIMPLE)
    {
    $str->{_cache} = undef;
    return;
    }
  print "next\n";
  my $overflow = 0;				# start with rightmost digit
  my $s = \$str->{_cache}->{str};
  my $len = CORE::length ($s);
  my $ss = $self->{_start};			# shortcut
  my $char;
  while ($overflow < $len)			# only for valid string chars
    {
    $char = $self->{_map}->{substr($$s,-$overflow,1)} + 1;
    if ($char > $ss)				# overflowed this pos?
      {
      substr($$s,-$overflow,1) = $ss->[0]; 	# reset this pos
      $overflow++;				# next
      }
    else
      {
      # correct str, and be done
      substr($$s,-$overflow,1) = $ss->[$char];
      }	
    }
  $$s = $ss->[0].$$s if $overflow > $len;	# extend string by one char
  #$str->{_cache} = undef;
  }

sub prev
  {
  my $self = shift;
  my $str = shift;

  # for higher orders not ready yet
  if ($self->{_order} != SIMPLE)
    {
    $str->{_cache} = undef;
    return;
    }
  $str->{_cache} = undef; 
  }

sub study
  {
  # study a list of words and return a hash describing them
  # study ( { order => $depth, words = \@words, sep => ''} );

  my $arg;
  ref $_[0] ? $arg = shift : $arg = { @_ };

  my $depth = abs($arg->{order} || 1);
  my $words = $arg->{words} || [];
  my $sep = $arg->{sep};
  my $charlen = $arg->{charlen} || 1;

  die "order must be between 1..2" if ($depth < 1 || $depth > 2);
  my $starts = {};              # word starts
  my $ends = {};                # word ends
  my $chars = {};               # for depth 1
  my $l; my $bi = { }; my (@chars,$x,$y,$word,$i);
  foreach $word (@$words)
    {
    # count starting chars and ending chars
    $starts->{substr($word,0,1)} ++;
    $ends->{substr($word,-1,1)} ++;
    @chars = split //, $word;
    if ($depth == 1)
      {
      foreach (@chars)
        {
        $chars->{$x} ++;
        }
      }
    $l = CORE::length($word) - $depth + 1;
    @chars = split //, $word;
    for ($i = 0; $i < $l; $i++)
      {
      $x = $chars[$i]; $y = $chars[$i+1];
      $bi->{$x}->{$y} ++;
      }
    }
  my $args = {};
  $starts = $chars if $depth == 1;
  my (@end,@start);
  foreach (sort { $starts->{$b} <=> $starts->{$a} } keys %$starts)
    {
    push @start, $_;
    }
  $args->{start} = \@start;
  foreach (sort { $ends->{$b} <=> $ends->{$a} } keys %$ends)
    {
    push @end, $_;
    }
  $args->{end} = \@end;
  if ($depth > 1)
    {
    my @sorted;
    foreach my $c (keys %$bi)
      {
      my $bc = $bi->{$c};
      $args->{bi}->{$c} = [
        sort { $bc->{$b} <=> $bc->{$a} or $a cmp $b } keys %$bc
        ];
      }
    }
  return $args;
  }

#############################################################################

=head1 NAME

Math::String::Charset - A charset for Math::String objects.

=head1 SYNOPSIS

    use Math::String::Charset;

    $a = new Math::String::Charset;		# default a-z
    $b = new Math::String::Charset ['a'..'z'];	# same
    $c = new Math::String::Charset 
	{ start => ['a'..'z'], sep => ' ' };	# with ' ' between chars

    print $b->length();				# a-z => 26

    # construct a charset from bigram table, and an initial set (containing
    # valid start-characters)
    # Note: After an 'a', either an 'b', 'c' or 'a' can follow, in this order
    #       After an 'd' only an 'a' can follow
    $bi = new Math::String::Charset ( { 
      start => 'a'..'d',
      bi => {
        'a' => [ 'b', 'c', 'a' ],
        'b' => [ 'c', 'b' ],
        'c' => [ 'a', 'c' ],
        'd' => [ 'a', ],
	'q' => [ ],			# 'q' will be automatically in end
        }
      end => [ 'a', 'b', ],
      } );
    print $bi->length();		# 'a','b' => 2 (cross of end and start)
    print scalar $bi->class(2);		# count of combinations with 2 letters
					# will be 3+2+2+1 => 8

=head1 REQUIRES

perl5.005, Exporter, Math::BigInt

=head1 EXPORTS

Exports nothing on default, can export C<study> and C<SIMPLE>.

=head1 DESCRIPTION

This module lets you create an charset object, which is used to contruct
Math::String objects. This object knows how to handle simple charsets as well
as complex onex consisting of bi-grams (later tri and more).

=over 1

=item Default charset

The default charset is the set containing "abcdefghijklmnopqrstuvwxyz"
(thus producing always lower case output).

=back

=head1 ERORRS

Upon error, the field C<_error> stores the error message, then die() is called
with this message. If you do not want the program to die (f.i. to catch the
errors), then use the following:

	use Math::String::Charset;

	$Math::String::Charset::die_on_error = 0;

	$a = new Math::String::Charset ();	# error, empty set!
	print $a->error(),"\n";

=head1 INTERNAL DETAILS

This object caches certain calculation results (f.i. the number of possible
combinations for a certain string length), thus greatly speeding up
sequentiell Math::String conversations from string to number, and vice versa.

=head2 CHARACTER LENGTH

All characters used to construct the charset must have the same length, but
need not neccessarily be one byte/char long.

=head2 COMPLEXITY

The complexity for converting from number to string, and vice versa,
is O(N), with N beeing the number of characters in the string.

Actually, it is a bit higher, since the underlying Math::BigInt needs more
time for longer numbers than for shorts. But usually the practically string
length limit is reached before this effect shows up.

See BENCHMARKS in Math::String for run-time details.

=head2 STRING ORDERING

With a simple charset, converting between the number and string is relatively
simple and straightforward, albeit slow.

With bigrams, this becomes even more complex. But since all the information
on how to convert between number and string in inside the charset definition,
Math::String::Charset will produce (and sometimes cache) this information.
Thus Math::String is simple a hull around Math::String::Charset and
Math::BigInt.

=head2 SIMPLE CHARSETS

Depending on the charset, the order in which Math::String 'sees' the strings
is different. Example with charset 'A'..'D':

          A      1
          B      2
          C      3
          D      4
         AA      5
         AB      6
         AC      7
         AD      8
         BA      9
         BB     10
         BC     11
         ..
        AAA     20
        AAB     21 etc

The order of characters does not matter, 'B','D','C','A' will produce similiar
results, though in a different order inside Math::String:

          B      1
          D      2
          C      3
          A      4
         BB      5
         BD      6
         BC      7
         ..
        BBB     20
        BBD     21 etc

Here is an example with characters of length 3:

	foo	 1
	bar	 2
	baz	 3
     foofoo	 4
     foobar	 5
     foobaz	 6
     barfoo      7
     barbar      8
     barbaz      9
     bazfoo	10
     bazbar	11
     bazbaz	12
  foofoofoo	13 etc

All charset items must have the same length, unless you use a separator string:
        
	use Math::String;

        $a = Math::String->new('', 
          { start => [ qw/ the green car a/ ], sep => ' ' } );

        while ($b ne 'the green car')
          {
	  $a ++;
          print "$a\t";         # print "a green car" etc
          }

The separator is a string, not a regexp and it must not be present in any
of the characters of the charset.

The old way was using a fill character, which is more complicated:

        use Math::String;

        $a = Math::String->new('', [ qw/ the::: green: car::: a:::::/ ]);

        while ($b ne 'the green car')
          {
          $a ++;
          print "$a\t";         # print "a:::::green:car:::" etc

          $b = "$a"; $b =~ s/:+/ /g; $b =~ s/\s+$//;
          print "$b\n";         # print "a green car" etc
          }

This produces:

	the:::  the
	green:  green
	car:::  car
	a:::::  a
	the:::the:::    the the
	the:::green:    the green
	the:::car:::    the car
	the:::a:::::    the a
	green:the:::    green the
	green:green:    green green
	green:car:::    green car
	green:a:::::    green a
	car:::the:::    car the
	car:::green:    car green
	car:::car:::    car car
	car:::a:::::    car a
	a:::::the:::    a the
	a:::::green:    a green
	a:::::car:::    a car
	a:::::a:::::    a a
	the:::the:::the:::      the the the
	the:::the:::green:      the the green
	the:::the:::car:::      the the car
	the:::the:::a:::::      the the a
	the:::green:the:::      the green the
	the:::green:green:      the green green
	the:::green:car:::      the green car

=head2 HIGHER ORDERS

Now imagine a charset that is defined as follows:

Starting characters for each string can be 'a','c','b' and 'd' (in that order).
Each 'a' can be followed by either 'b', 'c' or 'a' (again in that order),
each 'c can be followed by either 'c', 'd' (again in that order),
and each 'b' or 'd' can be followed by an 'a' (and nothing else).

The definition is thus:

        use Math::String::Charset;

        $cs = Math::String::Charset->new( {
                start => [ 'a', 'c', 'b', 'd' ],
                bi => {
                  'a' => [ 'b','c','a' ],
                  'b' => [ 'a', ],
                  'd' => [ 'a', ],
                  'c' => [ 'c','d' ],
                  }
                } );

This means that each character in a string depends on the previous character.
Please note that the probabilities on which characters follows how often which
character do not concern us here. We simple enumerate them all. Or put
differently: each probability is 1.

With the charset above, the string sequence runs as follows:

        string  number  count of strings
                        with length

          a       1
          c       2
          b       3
          d       4     1=4
         ab       5
         ac       6
         aa       7
         cc       8
         cd       9
         ba      10
         da      11     2=7
        aba      12
        acc      13
        acd      14
        aab      15
        aac      16
        aaa      17
        ccc      18
        ccd      19
        cda      20
        bab      21
        bac      22
        baa      23
        dab      24
        dac      25
        daa      26     3=15
       abab      27
       abac      28
       abaa      29
       accc      30
       accd      31
       acda      32
       aaba      33
       aacc      34
       aacd      35	etc


There are 4 strings with length 1, 7 with length 2, 15 with length 3 etc. Here
is an example for first() and last():

	$charset->first(3);	# gives aba
	$charset->last(3);	# gives daa

=head2 RESTRICTING STRING ENDINGS

Sometimes, you want to specify that a string can end only in certain
characters. There are two ways:

        use Math::String::Charset;

        $cs = Math::String::Charset->new( {
                start => [ 'a', 'c', 'b', 'd' ],
                bi => {
                  'a' => [ 'b','c','a' ],
                  'b' => [ 'a', ],
                  'd' => [ 'a', ],
                  'c' => [ 'c','d' ],
                  }
                end => [ 'a','b' ],
                } );

This defines any string ending not in 'a' or 'b' as invalid. The sequence runs
thus:

        string  number  count of strings
                        with length

          a       1
          b       2     2
         ab       4
         aa       5
         ba       6
         da       7     4
        aba       8
        aab       9
        aaa      10
        cda      11
        bab      12
        baa      13
        dab      14
        daa      15     8
       abab      16	
       abaa      17	etc

There are now only 2 strings with length 1, 4 with length 2, 8 with length 3
etc. 

The other way is to specify the (additional) ending restrictions implicit by
using chars that are not followed by other characters:
        
	use Math::String::Charset;

        $cs = Math::String::Charset->new( {
                start => [ 'a', 'c', 'b', 'd' ],
                bi => {
                  'a' => [ 'b','c','a' ],
                  'b' => [ 'a', ],
                  'd' => [ 'a', ],
                  'c' => [  ],
                  }
                } );

Since 'c' is not followed by any characters, there are no strings with a 'c'
in the middle (which means strings can end in 'c'):

        string  number  count of strings
                        with length

          a       1
          c       2
          b       3
          d       4     4
         ab       5
         ac       6
         aa       7
         ba       8
         da       9     5
        aba      10
        aab      11
        aac      12
        aaa      13
        bab      14
        bac      15
        baa      16
        dab      17
        dac      18
        daa      19     10
       abab      20
       abac      21 etc

There are now 4 strings with length 1, 5 with length 2, 10 with length 3
etc. 

Any character that is not followed by another character is automatically
added to C<end>. This is because otherwise you would have created a rendundand
character which could never appear in any string:

Let's assume 'q' is not in the C<end> set, and not followed by any other
character:

=over 2

=item 1

There can no string "q", since strings of lenght 1 start B<and> end with their
only character. Since 'q' is not in C<end>, the string "q" is invalid (no
matter wether 'q' appears in C<start> or not).

=item 2

No string longer than 1 could start with 'q' or have a 'q' in the middle,
since 'q' is not followed by anything. This leaves only strings with length
1 and these are invalid according to rule 1.

=back

=head2 CONVERTING (STRING <=> NUMBER)

From now on, a 'class' refers to all strings with the same length.
The order or length of a class is the length of all strings in it.

With a simple charset, each class has exactly M times more strings than the
previous class (e.g. the class with a length - 1). M is in this case the length
of the charset.

=head2 SIMPLE CHARSET

To convert between string and number, we must simple know which string has
which number and which number is which string. Although this sounds very
difficult, it is not so. With 'simple' charsets, it only involves a bit of
math. 

First we need to know how many string are in the class. From
this information we can determine the lenght of a string given it's number,
and get the range inside which the number to a string lies:

Let's stick to the example with 4 characters above, 'A'..'D':

        Stringlenght    strings with that length        first in range
        1               4                               1
        2               16 (4*4)                        5
        3               64 (4*4*4)                      21
        4               4**4                            85
        5               4**5 etc                        341

You see that this is easy to calculate. Now, given the number 66,
we can determine how long the string must be:

66 is greater than 21, but lower than 85, so the string must be 3 characters
long. This information is determined in O(N) steps, wheras N is the length
of the string by successive comparing the number to the elements in all
string of a certain length.

If we then subtract from 66 the 21, we get 45 and thus know it must be the
fourty-fifth string of the 3 character long ones.

The math involved to determine which 3 character-string it actually is
equally to converting between decimal and hexadecimal numbers. Please see
source for the gory, but boring details.

=head2 HIGHER ORDER CHARSETS

For charsets of higher order, even determining the number of all strings in a
class becomes more difficult. Fortunately, there is a way to do it in N steps
just like with a simple charset.

=head2 BASED ON ENDING COUNTS

The first way is based on the observation that the number of strings in class
n+1 only depends on the number of ending chars in class n, and nothing else.

This is, however, not used in the current implemenation, since there is a
slightly faster/simpler way based on the count of strings that start with a
given character in class n, n-11, n-2 etc. See below for a description.

Here is for reference the example with ending char counts:

        use Math::String::Charset;

        $cs = Math::String::Charset->new( {
                start => [ 'a', 'c', 'b', 'd' ],
                bi => {
                  'a' => [ 'b','c','a' ],
                  'c' => [ 'c','d' ],
                  'b' => [ 'a', ],
                  'd' => [ 'a', ],
                  }
                } );

        Class 1:
          a       1
          c       2
          b       3
          d       4     4

As you can see, there is one 'a', one 'c', one 'b' and one 'd'.
To determine how many
strings are in class 2, we must multiply the occurances of each character by
the number of how many characters it is followed:

        a * 3 + c * 2 + d * 1 + b * 1

which equals

        1 * 3 + 1 * 2 + 1 * 1 + 1 * 1

If we summ this all up, we get 3+2+1+1 = 7, which is exactly the number of
strings in class 2. But to determine now the number of strings in class 3,
we must now how many strings in class 2 end on 'a', how many on 'b' etc.

We can do this in the same loop, by not only keeping a sum, but by counting
all the different endings. F.i. exactly one string ended in 'a' in class 1.
Since 'a' can be followed by 3 characters, for each character we know that it
will occure at least 1 time. So we add the 1 to the character in question.

        $new_count->{'b'} += $count->{'a'};

This yields the amounts of strings that end in 'b' in the next class.

We have to do this for every different starting character, and for each of the
characters that follows each starting character. In the worst case this means
M*M steps, while M is the length of the charset. We must repeat this for each
of the classes, so that the complexity becomes O(N*M*M) in the worst case.
For strings of higher order this gets worse, adding a *M for each higher order.

For our example, after processing 'a', we will have the following counts for
ending chars in class 2:

        b => 1
        c => 1
        a => 1

After processing 'c', it is:

        b => 1
        c => 2 (+1)
        a => 1
        d => 1 (+1)

because 'c' is followed by 'd' or 'c'. When we are done with all characters,
the following count's are in our $new_count hash:

        b => 1
        c => 2
        a => 3
        d => 1

When we sum them up, we get the count of strings in class 2. For class 3, we
start with an empty count hash again, and then again for each character
process the ones that follow it. Example for a:

        b => 0
        c => 0
        a => 0
        d => 0

3 times ending in 'a' followed by 'b','c' or 'd':

        b => 3  (+3)
        c => 3  (+3)
        a => 3  (+3)
        d => 0

2 times ending 'c' followed by 'c' or 'd':

        b => 3
        c => 5  (+2)
        a => 3
        d => 2  (+2)

After processing 'b' and 'd' in a similiar manner we get:

        b => 3
        c => 5
        a => 5
        d => 2

The sum is 15, and we know now that we have 15 different strings in class 3.
The process for higher classes is the same again, re-using the counts from the
lower class.

=head2 BASED ON STARTING COUNTS

The second, and implemented method counts for each class how many strings
start with a given character. This gives us two information at once:

=over 2

=item *

A string of length N and a starting char of X, which number it must have at
minimum (by summing up the counts of all strings that come before X) and how
many strings are there starting with X (although this is not used for X, but
only for all strings that come after X).

=item *

How many strings are there with a given length, by summing up all the counts
for the different starting chars.

=back

This method also has the advantage that it doesn't need to re-calculate
the count for each level. If we have cached the information for class 7,
we can calculate class 8 right-away. The old method would either need to start
at class 1, working up to 8 again, or cache additional information of the order
N (where N is the number of different characters in the charset).

Here is how the second method works, based on the example above:

                start => [ 'a', 'c', 'b', 'd' ],
                bi => {
                  'a' => [ 'b','c','a' ],
                  'c' => [ 'c','d' ],
                  'b' => [ 'a', ],
                  'd' => [ 'a', ],
                  }

The sequence runs as follows:

	String	Strings starting with
		this character in this level

	  a	1
	  c	1
	  b	1
	  d	1
	 ab
	 ac	
	 aa	3	(1+1+1)
	 cc
	 cd	2	(1+1)
	 ba	1	
	 da	1	
	aba
	acc
	acd
	aab
	aac
	aaa	6	1 (b) + 2 (c) + 3 (a)
	ccc
	ccd
	cda	3	2 (c) + 1 (d)
	bab
	bac
	baa	3
	dab
	dac
	daa	3
       abab			
       abac			
       abaa			
       accc	etc

As you can see, for length one, there is exactly one string for each starting
character.

For the next class, we can find out how many strings start with a given char,
by adding together all the counts of strings in the previous class.

F.i. in class 3, there are 6 strings starting with 'a'. We find this out by
adding together 1 (there is 1 string starting with 'b' in class 2), 2 (there
are two strings starting with 'c' in class 2) and 3 (three strings starting
with 'a' in class 2).

As a special case we must throw away all strings in class 2 that have invalid
ending characters. By doing this, we automatically have restricted B<all>
strings to only valid ending characters. Therefore, class 1 and 2 are setup
upon creating the charset object, the others are calculated on-demand and then
cached.

Since we are calculating the strings in the order of the starting characters,
we can sum up all strings up to this character.
	
	String	First string in that class

	  a	0
	  c	1
	  b	2
	  d	3

	 ab	0
	 ac	
	 aa		
	 cc	3
	 cd		
	 ba	5	
	 da	6
	
	aba	0
	acc
	acd
	aab
	aac
	aaa	
	ccc	6
	ccd
	cda	
	bab	9
	bac
	baa	
	dab	12
	dac
	daa	
       abab	0
       abac	
       abaa
       accc	etc

When we add to the number of the last character (f.i. 12 in case of 'd' in
class 3) the amount of strings with that character (here 3), we end up with
the number of all strings in that class.

Thus in the same loop we calculate:

=over 2

=item how many stings start with a given character in this class

=item what is the first number of a string starting with 'x' in that class

=item how many strings are in this class at all

=back

That is all we need to know to convert a string to it's number.

=head2 HIGHER ORDER CHARSETS, FINDING THE RIGHT NUMBER

From the section above we know that we can find out which number a string
of a certain class has at minimum and at maximum. But what number has the
string in that range, actually?

Well, given the information it is easy. First, find out which minimum number a
string has with the given starting
character in the class. Add this to it's base number. Then reduce the class by
one, look at the next character and repeat this.  In pseudo code:

	$class = length ($string); $base = base_number->[$class];
	foreach ($character)
	  {
	  $base += $sum->[$class]->{$character};
	  $class --;
	  }

So, after N simple steps (where N is the number of characters in the string),
we have found the number of the string.

=head2 HIGHER ORDER CHARSETS, FINDING THE RIGHT STRING

Section not ready yet.

=head2 MULTIPLE MULTIWAY TREES

It helps to imagine the strings like a couple of trees (ASCII art is crude):

        class:  1   2    3   etc

       number
        1       a
          5     +--ab
           12   |   +--aba
          6     +--ac
           13   |   +--acc
           14   |   +--acd
          7     +--aa
           15       +--aab
           16       +--aac
           17       +--aaa

        2       c
          8     +--cc
           18   |   +--ccc
           19   |   +--ccd
          9     +--cd
           20       +--cda

        3       b
         10     +--ba
           21       +--bab
           22       +--bac
           23       +--baa

        4       d
         11     +--da
           24       +--dab
           25       +--dac
           26       +--daa

As you can see, there is a (independend) tree for each of the starting
characters, which in turn contains independed sub-trees for each string in
the next class etc. It is interesting to note that each string deeper in the
tree starts with the same common starting string, aka 'd', 'da', 'dab' etc.

With a simple charset, all these trees contain the same number of nodes. With
higher order charsets, this is no longer true.

=head1 METHODS

=head2 B<new()>

            new();

Create a new Math::Charset object. 

The constructor takes either an ARRAY or a HASH reference. In case of the
array, all elements in that array will be used as characters in the charset.

If given a HASH reference, the following keys will be used:

	order		order of the charset, defaults to 1
	sep		separator character, none if undef (only for order 1)
	start		all valid starting characters

For charsets of an order greater than 1, the following keys will also be used:
	
	bi		table with bi-grams
	end		all valid ending characters

=over 2

=item start

C<start> contains an array reference to all valid starting
characters, e.g. no valid string can start with a character not listed here.

=item bi

C<bi> contains a hash reference, each key of the hash points to an array,
which in turn contains all the valid combinations of two letters.

=item end

C<start> contains an array reference to all valid ending
characters, e.g. no valid string can end with a character not listed here.
Note that strings of length 1 start B<and> end with their only
character, so the character must be listed in C<end> and C<start> to produce
a string with one character.
Also all characters that are not followed by any other character are added
silently to the C<end> set.

=back

=head2 B<length()>

	$charset->length();

Return the number of items in the charset, for higher order charsets the
number of valid 1-character long strings. Shortcut for 
C<< $charset->class(1) >>.

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

Return the type/order of the charset: 1 for simple charsets, 2, 3 etc for higher
orders.

=head2 B<charlen()>

	$character_length = $charset->charlen();

Return the length of one character in the set. 1 or greater.

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

In list context, returns a list of all characters in the start set, for simple
charsets (e.g. no bi, tri-grams etc) simple returns the charset. In scalar
context returns the lenght of the start set.

=head2 B<end()>

	$charset->end();

In list context, returns a list of all characters in the end set, aka all
characters a string can end with. For simple charsets (e.g. no bi, tri-grams
etc) simple returns the charset. In scalar context returns the lenght of the
end set.

Note that the returned end set can be differen from what you specified upon
constructing the charset, because characters that are not followed by any other
character will be included in the end set, too.

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

=head2 B<study()>

	$hash = Math::String::Charset::study( {
          order => $order, words => \@words, sep => 'separator',
          charlen => 1, } );

Studies the given list of strings/words and builds a hash that you can use
to construct a charset of. The C<order> is 1 for simple charsets, 2 for bigrams
and so on. C<separator> (can be undef) is the sting that separates characters.
C<charlen> is the length of a character, and defaults to 1. Use this if you
have characters longer than one and no separator string.

Instead passing an array ref as words, you can as well pass a hash ref. The
keys in the hash will be used as words then. This is so that you can clean out
doubles by using a hash and pass it to study without converting it to an array
first.

=head1 EXAMPLES

    use Math::String::Charset;

    # construct a charset from bigram table, and an initial set (containing
    # valid start-characters)
    # Note: After an 'a', either an 'b', 'c' or 'a' can follow, in this order
    #       After an 'd' only an 'a' can follow
    #       There is no 'q' as start character, but 'q' can follow 'd'!
    #       You need to define followers for 'q'!
    $bi = new Math::String::Charset ( { 
      start => 'a'..'d',
      bi => {
        'a' => [ 'b', ],
        'b' => [ 'c', 'b' ],
        'c' => [ 'a', 'c' ],
        'd' => [ 'a', 'q' ],
	'q' => [ 'a', 'b' ],
        }
      } );
    print $bi->length(),"\n";			# 4
    print scalar $bi->combinations(2),"\n";	# count of combos with 2 chars
						# will be 1+2+2+2+2 => 9
    my @comb = $bi->combinations(3);
    foreach (@comb)
      {
      print "$_\n";
      }

This will print:

	4
	7
	abc
	abb
	bca
	bcc
	bbc
	bbb
	cab
	cca
	ccc
	dab
	dqa
	dqb

Another example using characters of different length to find all combinations
of words in a list:

	#!/usr/bin/perl -w

	# test for Math::String and Math::String::Charset

	BEGIN { unshift @INC, '../lib'; }

	use Math::String;
	use Math::String::Charset;
	use strict;

	my $count = shift || 4000;

	my $words = {};
	open FILE, 'wordlist.txt' or die "Can't read wordlist.txt: $!\n";
	while (<FILE>)
	  {
	  chomp; $words->{lc($_)} ++;	# clean out doubles
	  }
	close FILE;
	my $cs = new Math::String::Charset ( { sep => ' ',
	   words => $words,
	  } );

	my $string = Math::String->new('',$cs);

	print "# Generating first $count strings:\n";
	for (my $i = 0; $i < $count; $i++)
	  {
	  print ++$string,"\n";
	  }
	print "# Done.\n";

=head1 TODO

=over 2

=item *

Currently only bigrams are supported. This should be generic and arbitrarily
deeply nested.

=item *

C<study()> does not yet work with separator chars and chars longer than 1.

=item *

str2num and num2str do not work fully for bigrams yet.

=back

=head1 BUGS

None doscovered yet.

=head1 AUTHOR

If you use this module in one of your projects, then please email me. I want
to hear about how my code helps you ;)

This module is (C) Copyright by Tels http://bloodgate.com 2000-2001.

=cut

1;
