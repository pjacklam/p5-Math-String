#!/usr/bin/perl -w

use strict;
use Test;

BEGIN 
  { 
  $| = 1;
  # chdir 't' if -d 't';
  unshift @INC, '../lib'; # to run manually
  plan tests => 79;
  }

use Math::String;
use Math::BigInt;

my (@args,$try,$rc,$x,$y,$z,$i,$res);
$| = 1;
while (<DATA>) 
  {
  chop;
  @args = split(/:/,$_,99);

  # test String => Number
  $try = "\$x = Math::String->new('$args[0]', [ $args[1] ] )->as_number();";

  $rc = eval $try; 

  # stringify returns undef instead of NaN
  $res = $args[2]; $res = undef if $args[2] eq 'NaN';
  print "# For '$try'\n" if (!ok "$rc" , $args[2]);
 
  # test Number => String
  next if $args[2] eq 'NaN'; # dont test NaNs reverse 
  $try = "\$x = Math::String::from_number('$args[2]', [ $args[1] ]);";
              
  $rc = eval $try;
  print "# For '$try'\n" if (!ok "$rc" , "$args[0]");

  }
close DATA;

##############################################################################
# check wether cmp and <=> work
$x = Math::String->new ('a');	# 1
$y = Math::String->new ('z');	# 26
$z = Math::String->new ('a');	# 1 again

ok ($x < $y, 1);	# ok (1 < 26, 1)
ok ($x > $y, '');	# ok (1 > 26, '')
ok ($x <=> $y, -1); 	# ok (1 <=> 26, -1)
ok ($y <=> $x, 1); 	# ok (26 <=> 1, 1)
ok ($x <=> $x, 0); 	# ok (1 <=> 1, 1)
ok ($x <=> $z, 0); 	# ok (1 <=> 1, 1)

ok ($x lt $y, 1); 	# ok ('a' lt 'z', 1);
ok ($x gt $y, '');	# ok ('z' lt 'a', '');
ok ($x cmp $y, -1);	# ok ('a' cmp 'z', -1);
ok ($y cmp $x, 1);	# ok ('z' cmp 'a', 1);
ok ($x cmp $x, 0);
ok ($x cmp $z, 0);

##############################################################################
# check if negative numbers give same output as positives
$try =  "\$x = Math::String::from_number(-12, ['0'..'9']); \$x->as_number();";
$rc = eval $try;
print "# For '$try'\n" if (!ok "$rc" , '-12');
$try =  '$x = Math::String::from_number(-12,["0".."9"]);';
$try .= '$y = Math::String::from_number(12,["0".."9"]); "true" if "$x" eq "$y";';
$rc = eval $try;
print "# For '$try'\n" if (!ok "$rc" , 'true');

##############################################################################
# check wether ++ and -- work
$try =  '$x = Math::String->new("z",["a".."z"]);';
$try =  '$y = $x; $y++; "true" if $x < $y;';

$rc = eval $try;
print "# For '$try'\n" if (!ok "$rc" , 'true');
  
$try =  '$x = Math::String->new("z",["a".."z"]);';
$try =  '$y = $x; $y++; $y--; "true" if $x == $y;';
$rc = eval $try;
print "# For '$try'\n" if (!ok "$rc" , 'true');

##############################################################################
# check wether bior(),bxor(), band() word
$x = Math::String->new("a");
$y = Math::String->new("b"); $z = $y | $x;
print "# For '\$z = $y | $x'\n" if (!ok "$z" , 'c');

$x = Math::String->new("b");
$y = Math::String->new("c"); $z = $y & $x;
print "# For '\$z = $y & $x'\n" if (!ok "$z" , 'b');

$x = Math::String->new("d");
$y = Math::String->new("e"); $z = $y ^ $x;
print "# For '\$z = $y ^ $x'\n" if (!ok "$z" , 'a');

##############################################################################
# check objectify of additional params

$x = Math::String->new('x');
$x->badd('a');			# 24 +1

ok ($x->as_number(),25);
$x->badd(1);			# can't add numbers 
				# ('1' is not a valid Math::String here!)
ok ($x->as_number(),'NaN');

ok ($x->order(),1);		# SIMPLE

$x = Math::String->new('x');
$x->badd( new Math::BigInt (1) ); # 24 +1 = 25
ok ($x,'y');

##############################################################################
# check if output of bstr is again a valid Math::String
for ($i = 1; $i<42; $i++)
  {
  $try = "\$x = Math::String::from_number($i,['0'..'9']);";
  $try .= "\$x = Math::String->new(\"\$x\",['0'..'9'])->as_number();";
  $rc = eval $try;
  print "# For '$try'\n" if (!ok "$rc" , $i );
  }

##############################################################################
# check overloading of cmp

$try = "\$x = Math::String->new('a'); 'true' if \$x eq 'a';";
$rc = eval $try;
print "# For '$try'\n" if (!ok "$rc" , "true" );

# check wether cmp works for other objects
$try = "\$x = Math::String->new('00',['0'..'9']);";
$try .= "\$y = Math::BigInt->new('10');";
$try .= "'false' if \$x ne \$y;";
$rc = eval $try;
print "# For '$try'\n" if (!ok "$rc" , "false" );

##############################################################################
# check $string->length()

$try = "\$x = Math::String->new('abcde'); \$x->length();";
$rc = eval $try;
print "# For '$try'\n" if (!ok "$rc" , 5 );

$try = "\$x = Math::String->new('foo bar foo ',";
$try .= " { sep => ' ', start => ['foo','bar'] } ); \$x->length();";
$rc = eval $try;
print "# For '$try'\n" if (!ok "$rc" , 3 );

$try = "\$x = Math::String->new('foobarfoo', ['foo','bar']); \$x->length();";
$rc = eval $try;
print "# For '$try'\n" if (!ok "$rc" , 3 );

##############################################################################
# overloading ==

$x = Math::String->new('a');
ok ($x == 1,1);

##############################################################################
# as_number

$x = Math::String->new('abc'); 
ok (ref($x->as_number()),'Math::BigInt');

##############################################################################
# accuracy/precicison

ok_undef ($Math::String::accuracy);
ok_undef ($Math::String::precision);
ok ($Math::String::fallback,40);
ok ($Math::String::rnd_mode,'even');

# all done

###############################################################################
# Perl 5.005 does not like ok ($x,undef)

sub ok_undef
  {
  my $x = shift;

  ok (1,1) and return if !defined $x;
  ok ($x,'undef');
  }

1;

__DATA__
abc:'0'..'9':NaN
abc:'a'..'b':NaN
abc:'a'..'c':18
