#!/usr/bin/perl -w

#############################################################################
# Math/String.pm -- package which defines a base class for calculating
# with big integers that are defined by arbitrary char sets.
#
# Copyright (C) 1999-2001 by Tels. All rights reserved.
#############################################################################

# see:
# http://www.xray.mpe.mpg.de/mailing-lists/perl5-porters/2000-05/msg00974.html
# vkonovalov@lucent.com 
# http://www.xray.mpe.mpg.de/mailing-lists/perl5-porters/1999-02/msg00812.html
# BDoucette@tesent.com
# mjd@plover.com

# the following hash values are used
# _set			  : ref to charset object
# sign, value, _a, _f, _p : from BigInt 
# _cache		  : hash, cache's the string and certain other values
#			  : for faster bstr() and add/dec

package Math::String;
my $class = "Math::String";

use Exporter;
use Math::BigInt;
@ISA = qw(Exporter Math::BigInt);
@EXPORT_OK = qw( as_number last first string from_number bzero
               );
#@EXPORT = qw( );
use Math::String::Charset;
use strict;
use vars qw($VERSION $AUTOLOAD $accuracy $precision $fallback $rnd_mode);
$VERSION = 1.12;    # Current version of this package
require  5.005;     # requires this Perl version or later

$accuracy = undef;
$precision = undef;
$fallback = 40;
$rnd_mode = 'even';

use overload
'cmp'   =>      sub { $_[2]?
              $_[1] cmp Math::String::bstr($_[0]) :
              Math::String::bstr($_[0]) cmp $_[1] },
# can modify arg of ++ and --, so avoid a new-copy for speed
'++'    =>      sub { Math::BigInt::badd($_[0],Math::BigInt->_one()) },
'--'    =>      sub { Math::BigInt::badd($_[0],Math::BigInt->_one('-')) },

;         

# some shortcuts for easier life
sub string
  {
  # exportable version of new
  return $class->new(@_);
  }

sub from_number
  {
  # turn an integer into a string object
  # catch Math::String->from_number and make it work
  my $val = shift; 

  # if ref to self, simple copy us to the value
  if (ref $val)
    {
    #my $self;
    #print "bstring bzero: $self $_[0]\n";
    #$self = $val; $self = $_[0]->copy();
    #print "$self\n";
    #return $self = $val->copy();
    my $self = $val; $val = shift;
    $val = Math::BigInt->new($val) unless ref $val =~ /Math::BigInt/;
    foreach my $k (keys %$val)
      {
      if (ref($val->{$k}) eq 'ARRAY') 
        {
        $self->{$k} = [ @{$val->{$k}} ];
        }
      else
        {
        $self->{$k} = $val->{$k};
        }
      }
    #print "$self $val\n";
    }
  else
    {
    $val = "" if !defined $val;
    $val = shift if !ref($val) && $val eq $class;
    #$val = shift if $val eq $class;
    my $self = Math::BigInt->new($val);
    bless $self, $class;         # rebless
    $self->_set_charset(shift);
    return $self; 
    }
  }

sub bzero
  {
  my $self = shift;
  if (defined $self)
    {
    # $x->bzero();	(x) (M::S)
    # $x->bzero();	(x) (M::bi or something)
    $self->SUPER::bzero();
    bless $self, $class if ref($self) ne $class;         # convert aka rebless
    }
  else
    {
    # M::S::bzero();	()
    $self = Math::BigInt::bzero();
    bless $self, $class;
    $self->_set_charset(shift);
    }
  $self->{_cache}->{str} = '';
  return $self;
  }

sub bnan
  {
  my $self = shift;
  if (defined $self)
    {
    # $x->bnan();	(x) (M::S)
    # $x->bnan();	(x) (M::bi or something)
    $self->SUPER::bnan();
    bless $self, $class if ref($self) ne $class;         # convert aka rebless
    }
  else
    {
    # M::S::bnan();	()
    $self = $class->SUPER::bnan();
    bless $self, $class;
    $self->_set_charset(shift);
    }
  $self->{_cache} = undef;
  return $self;
  }

sub binf
  {
  my $self = shift;
  if (defined $self)
    {
    # $x->bzero();	(x) (M::S)
    # $x->bzero();	(x) (M::bi or something)
    $self->SUPER::binf(shift);
    bless $self, $class if ref($self) ne $class;         # convert aka rebless
    }
  else
    {
    # M::S::bzero();	()
    $self = $class->SUPER::binf(shift);
    bless $self, $class;
    $self->_set_charset(shift);
    }
  $self->{_cache} = undef;
  return $self;
  }

###############################################################################
# constructor

sub new
  {
  my $class = shift;
  $class = ref($class) || $class;
  my $value = shift; $value = '' if !defined $value;

  my $self = {};
  #print "$class new($value)\n";
  if (ref($value))
    {
    #print "new from ref: ",ref($value),"\n";
    $self = $value->copy(); 		# got an object, so make copy
    bless $self, $class;		# rebless
    $self->_set_charset(shift);		# if given charset, copy over
    $self->{_cache} = undef;
    }
  else
    {
    #print "non ref new\n";
    bless $self, $class;
    $self->_set_charset(shift);
    $self->_initialize($value);
    #print "result of new $self\n";
    }
  #print "after new: ",ref($self),"\n";
  #foreach (keys %$self)
  #  {
  #  print "new $_ => $self->{$_}\n";
  #  }
  return $self; 
  }

sub _set_charset
  {
  # store reference to charset object, or make one if given array/hash ref
  # first method should be prefered for speed/memory reasons
  my $self = shift;
  my $cs = shift;

  $cs = ['a'..'z'] if !defined $cs;		# default a-z
  $cs = Math::String::Charset->new( $cs ) if ref($cs) =~ /^(ARRAY|HASH)$/;
  die "charset '$cs' is not a reference" unless ref($cs);
  $self->{_set} = $cs;
  return $self;
  }

#############################################################################
# private, initialize self 

sub _initialize
  {
  # set yourself to the value represented by the given string
  my $self = shift;
  my $value = shift;

  my $cs = $self->{_set};

  return $self->bnan() if !$cs->is_valid($value);
 
  my $int = $cs->str2num($value);
  foreach my $c (keys %$int) { $self->{$c} = $int->{$c}; }
  
  $self->{_cache}->{str} = $value;	# caching string form
  # print "caching $value\n"; 
  return $self;
  }

sub charset
  {
  my $self = shift;
  return $self->{_set};
  }

sub length
  {
  # return number of characters in output
  my $x = shift;
  return $x->{_set}->chars($x);
  }

sub bstr
  {
  my $x = shift;

  return $x unless ref $x;			# scalars get simple returned
  return undef if $x->{sign} !~ /^[+-]$/;	# short cut
  return '' if $x->is_zero();			# short cut

  return $x->{_cache}->{str} if defined $x->{_cache}->{str};
  # num2str needs (due to overloading "$x-1") a Math::BigInt object, so make it 
  # positively happy
  my $int = Math::BigInt::bzero();
  # $int->{sign} = '+';
  $int->{value} = $x->{value};
  return $x->{_set}->num2str($int);
  }

sub as_number
  {
  my $self = shift;

  # return yourself as MBI
  return Math::BigInt->new($self->SUPER::bstr());
  }

sub order
  {
  my $x = shift;
  return $x->{_set}->order();
  }

sub last
  {
  my $x = shift;

  my $es = $x->{_set}->last(@_);
  return $x->_initialize($es);
  }

sub first
  {
  my $x = shift;
  my $es = $x->{_set}->first(@_);
  return $x->_initialize($es);
  }

sub error
  {
  my $x = shift;
  return $x->{_set}->error();
  }

#############################################################################
# cache management

sub modify
  {
  my $self = shift;
  my $method = shift;

  if ($method =~ /^(bdec|binc)$/)
    {
    # update cache instead of invalidating it
    if ($method eq 'bdec')
      {
      $self->{_set}->prev($self);
      }
    else
      {
      $self->{_set}->next($self);
      }
    }
  else
    {
    # invalidate cache if $self is going to be modified
    $self->{_cache} = undef;
    }
#  print "m::s $self modify by $method\n";
  return 0;	# go ahead, modify
  }

#############################################################################

=head1 NAME

Math::String - Arbitrary sized integers having arbitrary charsets to calculate with password/key rooms.

=head1 SYNOPSIS

    use Math::String;

    $a = new Math::String 'cafebabe';  	# default a-z
    $b = new Math::String 'deadbeef';  	# a-z
    print $a + $b;                     	# Math::String ""
   
    $a = new Math::String 'aa';        	# default a-z
    $b = $a; 
    $b++; 
    print "$b > $a" if ($b > $a);      	# prove that ++ makes it greater
    $b--; 
    print "$b == $a" if ($b == $a);    	# and that ++ and -- are reverse

    $d = Math::String->bzero( ['0'...'9'] );   	# like Math::Bigint
    $d += Math::String->new ( '9999', [ '0'..'9' ] ); 
					# Math::String "9999"  

    print "$d\n";                      	# string       "00000\n"
    print $d->as_number(),"\n";        	# Math::BigInt "+11111"
    print $d->last(5),"\n";            	# string       "99999"
    print $d->first(3),"\n";           	# string       "111"
    print $d->length,"\n";             	# faster than length("$d");

=head1 REQUIRES

perl5.005, Exporter, Math::BigInt, Math::String::Charset

=head1 EXPORTS

Exports nothing on default, but can export C<as_number()>, C<string()>,
C<first()>, C<digits()>, C<from_number>, C<bzero()> and C<last()>.

=head1 DESCRIPTION

This module lets you calculate with strings (specifically passwords, but not
limited to) as if they were big integers. The strings can have arbitrary
length and charsets. Please see L<Math::String::Charset> for full documentation
on possible character sets.

You can thus quickly determine the number of passwords for brute force 
attacks, divide key spaces etc.

=over 1

=item Default charset

The default charset is the set containing "abcdefghijklmnopqrstuvwxyz"
(thus producing always lower case output).

=back

=head1 INTERNAL DETAILS

Uses internally Math::BigInt to do the math, all with overloaded operators. For
the character sets, Math::String::Charset is used.

Actually, the 'numbers' created by this module are NOT equal to plain 
numbers.  It works more than a counting sequence. Oh, well, example coming:

Imagine a charset from a-z (26 letters). The number 0 is defined as '', the
number one is therefore 'a' and two becomes 'b' and so on. And when you reach
'z' and increment it, you will get 'aa'. 'ab' is next and so on forever. 

That works a little bit like the automagic in ++, but more consistent and 
flexible. The following example 'breaks' (no, >= instead of gt won't help ;)

	$a = 'z'; $b = $a; $a++; print ($a gt $b ? 'greater' : 'lower');

With Math::String, it does work as intended, you just have to use '<' or
'>' etc for comparing. That was also the main reason for this module ;o)

incidentily, '--' as well most other mathematical operations work as you
expected them to work on big integers.

Compare a Math::String of charset '0-9' sequence to that of a 'normal' number:

    ''   0                       0            
    '0'  1                       1
    '1'  2                       2
    '2'  3                       3
    '3'  4                       4
    '4'  5                       5
    '5'  6                       6
    '6'  7                       7
    '7'  8                       8
    '8'  9                       9 
    '9'  10                     10 
   '00'  11                1*10+ 1
   '01'  12                1*10+ 2
       ...
   '98'  109               9*10+ 9
   '99'  110               9*10+10
  '000'  111         1*100+1*10+ 1
  '001'  112         1*100+1*10+ 2
       ...
 '0000'  1111  1*1000+1*100+1*10+1
       ...
 '1234'  2345  2*1000+3*100+4*10+5

And so on. Here is another example that shows how it works with a number
having 4 digits in each place (named "a","b","c", and "d"):

     a    1           1
     b    2           2
     c    3           3
     d    4           4
    aa    5       1*4+1
    ab    6       1*4+2
    ac    7       1*4+3    
    ad    8       1*4+4
    ba    9       2*4+1
    bb   10       2*4+2
    bc   11       2*4+3
    bd   12       2*4+4
    ca   13       3*4+1
    cb   14       3*4+2
    cc   15       3*4+3
    cd   16       3*4+4
    da   17       4*4+1
    db   18       4*4+2
    dc   19       4*4+3
    dd   20       4*4+4 
   aaa   21  1*16+1*4+1

Here is one with a charset containing 'characters' longer than one, namely
the words 'foo', 'bar' and 'fud':

	   foo		 1
	   bar		 2
	   fud		 3
	foofoo		 4
	foobar		 5
	foofud		 6
	barfoo		 7
	barbar		 8
	barfud		 9
	fudfoo		10
	fudbar		11
	fudfud		12
     foofoofoo		13 etc

The number sequences are symmetrical to 0, e.g. 'a' is both 1 and -1.
Internally the sign is stored and honoured, only on conversation to string it
is lost. 

The caveat is that you can NOT use Math::String to work, let's say with 
hexadecimal numbers. If you do calculate with Math::String like you would
with 'normal' hexadecimal numbers (any base would or rather, would not do),
the result may not mean anything and can not nesseccarily compared to plain
hexadecimal math.

The charset given upon creation need not be a 'simple' set consisting of all
the letters. You can, actually, give a set consisting of bi-, tri- or higher
grams. 

See Math::String::Charset for examples of higher order charsets and charsets
with more than one character per, well, character.

=head1 USEFULL METHODS

=head2 B<new()>

            new();

Create a new Math::String object. Arguments are the value, and optional
charset. The charset is set to 'a'..'z' as default. 

Since the charset caches some things, it is much better to give an already
existing Math::String::Charset object to the contructor, instead of creating
a new one for each Math::String. This will save you memory and computing power.
See http://bloodgate.com/perl/benchmarks.html for details, and
L<Math::String::Charset> for how to construct charsets.

=head2 B<order()>

            $string->order();

Return the type/order of the string derived from the underlying charset. 
1 for SIMPLE (or order 1), 2 for bi-grams etc.

=head2 B<first()>

            $string->first($length);

It is a bit tricky to get the first string of a certain length, because you
need to consider the charsets at each digit. This method sets the given
Math::String object to the first possible string of the given length. 
The length defaults to 1.

=head2 B<last()>

            $string->last($length);

It is a bit tricky to get the last string of a certain length, because you
need to consider the charsets at each digit. This method sets the given
Math::String object to the last possible string of the given length. 
The length defaults to 1.

=head2 B<as_number()>

            $string->as_number();

Return internal number as normalized string including sign. 

=head2 B<from_number()>

            $string = Math::String::from_number(1234,$charset);

Create a Math::String from a given integer value and a charset.

=head2 B<bzero()>

            $string = Math::String::bzero($charset);

Create a Math::String with the number value 0 (evaluates to '').

=head2 B<length()>

            $string->length();

Return the number of characters in the resulting string (aka it's length). This
is faster than doing C<length("$string");> because it doesn't actually create
the string version from the internal number representation.

Note: The length() will be always in characters. If your characters in the
charset are longer than one byte/character, you need to multiply the length
by the character length. This is nearly impossible, if your characterset has
characters with different lengths (aka if it has a separator character). In
this case you need to construct the string to find out the actual length in
bytes. 

=head2 B<bstr()>

            $string->bstr();

Return a string representing the internal number with the given charset.
Since this omitts the sign, you can not distinguish between negative and 
positiv values. Use C<as_number()> or C<sign()> if you need the sign.

This returns undef for 'NaN', since with a charset of
[ 'a', 'N' ] you would not be able to tell 'NaN' from true 'NaN'!
'+inf' or '-inf' return undef for the same reason.

=head2 B<charset()>

            $string->charset();

Return a reference to the charset of the Math::String object.

=head2 B<string()>

            Math::String->string();

Just like new, but you can import it to save typing.

=head1 LIMITS

For the actual math, the same limits as in L<Math::BigInt> apply. Negative
Math::Strings are possible, but produce no different output than positive.
You can use C<as_number()> or C<sign()> to get the sign, or do math with
them, of course.

Also, the limits detailed in L<Math::String::Charset> apply, like:

=over 1

=item No doubles

The sets must not contain doubles. With a set of "eerr" you would not
be able to tell the output "er" from "er", er, if you get my drift...

=item Charset items

All charset items must have the same length, unless you specify a separator
string:

	use Math::String;

	$b = Math::String->new( '', 
           { start => [ qw/ the green car a/ ], sep => ' ', }  
	   );

	while ($b ne 'the green car')
          {
	  print ++$b,"\n";	# print "a green car" etc
	  }

=item Objectify

Writing things like

        $a = Math::String::bsub('hal', 'aaa');

does not work, unlike with Math::BigInt (which just knows how to treat
the arguments to become BigInts). The first argument must be a 
reference to a Math::String object.

The following two lines do what you want and are more or less (except output)
equivalent:

        $a = new Math::String 'vms'; $a -= 'aaa';
        $a = new Math::String 'ibm'; $a->badd('aaa');

Also, things like

        $a = Math::String::bsub('hal', 5);

does not work, since Math::String can not decide whether 5 is the number 5,
or the string '5'. It could, if the charset does not contain '0'..'9', but
this would lead to confusion if you change the charset. So, the second paramter
must always be a Math::String object, or a string that is valid with the
charset of the first parameter. You can use C<Math::String::from_number()>:

        $a = Math::String::bsub('hal', Math::String::from_number(5) );

=back

=head1 EXAMPLES

Fun with Math::String:

	use Math::String;

	$ibm = new Math::String ('ibm');
	$vms = new Math::String ('vms');
	$ibm -= 'aaa';
	$vms += 'aaa';
	print "ibm is now $ibm\n";   
	print "vms is now $vms\n";   
	
Some more serious examples:

        use Math::String;
        use Math::BigFloat;

        $a = new Math::String 'henry';                  # default a-z
        $b = new Math::String 'foobar';                 # a-z

        # Get's you the amount of passwords between 'henry' and 'foobar'.
        print "a  : ",$a->as_numbert(),"\n";
        print "b  : ",$b->as_bigint(),"\n";
        $c = $b - $a; print $c->as_bigint(),"\n";

        # You want to know what is the first or last password of a certain
        # length (without multiple charsets this looks a bit silly):
        print $a->first(5),"\n";                        # aaaaa
        print Math::String::first(5,['a'..'z']),"\n";	# aaaaa
        print $a->last(5),"\n";                         # zzzzz
        print Math::String::last(5,['A'..'Z']),"\n";	# ZZZZZ

        # Lets assume you had a password of length 4, which contained a
        # Capital, some lowercase letters, somewhere either a number, or
        # one of '.,:;', but you forgot it. How many passwords do you need
        # to brute force in the worst case, testing every combination?
        $a = new Math::String '', ['a'..'z','A'..'Z','0'..'9','.',',',':',';'];
        # produce last possibility ';;;;;' and first 'aaaaa'
        $b = $a->last(4);   # last possibility of length 4
        $c = $a->first(4);  # whats the first password of length 4

        $c->bsub($b);
        print $c->as_bigint(),"\n";		# all of length 4
        print $b->as_bigint(),"\n";             # testing length 1..3 too

        # Let's say your computer can test 100.000 passwords per second, how
        # long would it take?
        $d = $c->bdiv(100000);
        print $d->as_bigint()," seconds\n";	#

        # or:
        $d = new Math::BigFloat($c->as_bigint()) / '100000';
        print "$d seconds\n";			#

        # You want your computer to run for one hour and see if the password
        # is to be found. What would be the last password to be tested?
        $c = $b + (Math::BigInt->new('100000') * 3600);
        print "Last tested would be: $c\n";    
        
        # You want to know what the 10.000th try would be
        $c = Math::String->from_number(10000,
         ['a'..'z','A'..'Z','0'..'9','.',',',':',';']);
	print "Try #10000 would be: $c\n";    

=head1 PERFORMANCE

For simple things, like generating all passwords from 'a' to 'zzz', this
is expensive and slow. A custom, table-driven generator or the build-in
automagic of ++ (if it would work correctly for all cases, that is ;) would
beat it anytime. But if you want to do more than just counting, then this
code is what you want to use. 

=head2 BENCHMARKS

See http://bloodgate.com/perl/benchmarks.html

=head1 PLANS

Support for more and different charsets.

=head1 BUGS

=over 2

=item *

Charsets with bi-grams do not work yet.

=item *

Adding/subtracting etc Math::Strings with different charsets treats the
second argument as it had the charset of the first. 

Only if the first charset contains all the characters of second string, you
could convert the second string to the first charset, but whether this is
usefull is questionable:

	use Math::String;

	$a = new Math::String ( 'a',['a'..'z']);	# is 1
	$z = new Math::String ( 'z',['z'..'a']);	# is 1, too

	$b = $a + $z;					# is 2, with set a..z
	$y = $z + $a;					# is 2, with set z..a

If you convert $z to $a's charset, you would get either an 1 ('a'),
or a 26 ('z'), and which one is more valid is unclear.  

=back

=head1 LICENSE

This program is free software; you may redistribute it and/or modify it under
the same terms as Perl itself.

=head1 AUTHOR

If you use this module in one of your projects, then please email me. I want
to hear about how my code helps you ;)

Tels http://bloodgate.com 2000-2001.

=cut

1;
