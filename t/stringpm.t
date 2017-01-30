#!/usr/bin/perl -w

use strict;
use Test;

BEGIN 
  { 
  $| = 1;
  # chdir 't' if -d 't';
  unshift @INC, '../lib'; # to run manually
  plan tests => 181;
  }

use Math::String;
use Math::BigInt;

my (@args,$try,$rc,$x,$y,$z,$i);
$| = 1;
while (<DATA>) 
  {
  chop;
  @args = split(/:/,$_,99);

  # print join(' ',@args),"\n";
  # test String => Number
  $try = "\$x = Math::String->new('$args[0]', [ $args[1] ] )->bstr()";
  $rc = eval $try; 

  # stringify returns undef instead of NaN
  if ($args[2] eq 'NaN')
    {
    print "# For '$try'\n" if (!ok_undef($rc));
    }
  else
    {
    print "# For '$try'\n" if (!ok "$rc" , $args[2]);
    }
 
  # test Number => String
  next if $args[2] eq 'NaN'; # dont test NaNs reverse 
  $try = "\$x = Math::String::from_number('$args[3]', [ $args[1] ]);";
              
  $rc = eval $try; print "# For '$try'\n" if (!ok "$rc" , "$args[0]");
  
  # test output as_number()
  if (defined $args[3])
    {
    $try = "\$x = Math::String->new('$args[0]', [ $args[1] ] )->as_number()";
    $rc = eval $try; print "# For '$try'\n" if (!ok "$rc" , $args[3]);
    }
  # test is_valid()
  $try  = "\$x = Math::String->new('$args[0]',[ $args[1] ]);";
  $try .= "\$x = \$x->is_valid();";
  $rc = eval $try; print "# For '$try'\n" if (!ok "$rc" , 1);

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

# overloading of <, <=, =>, >, <=>, ==, !=
$x = Math::String->new('a'); 
ok ($x == 'a',1); ok ($x != '',1);

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

###############################################################################
# stress-test ++ and -- since they use caching

# compare to build in ++
$x = Math::String->new('');
ok ($x,''); $a = 'a'; for ($i = 0; $i < 27; $i++) { ok (++$x,$a++); }

# inc/dec with sep chars
$x = Math::String->new('', Math::String::Charset->new( { 
  start => ['foo', 'bar', 'baz' ], sep => ' ' } ));
ok ($x,''); 
ok (++$x,'foo');
ok (++$x,'bar');
ok (++$x,'baz');
ok (++$x,'foo foo');
ok (++$x,'foo bar');
ok (++$x,'foo baz');
ok (++$x,'bar foo');
ok (++$x,'bar bar');
ok ($x,'bar bar');
ok (--$x,'bar foo');
ok (--$x,'foo baz');
ok (--$x,'foo bar');
ok (--$x,'foo foo');
ok (--$x,'baz');
ok (--$x,'bar');
ok (--$x,'foo');
ok (--$x,'');
ok (--$x,'foo');	# negative

# for minlen
$x = Math::String->new('', Math::String::Charset->new( { 
  start => ['a', 'b', 'c' ], minlen => 2, } ));
ok_undef ($x);

$x = Math::String->new('aa', Math::String::Charset->new( { 
  start => ['a', 'b', 'c' ], minlen => 2, } ));
ok ($x,'aa');		# smallest possible
ok_undef (--$x,'hm2'); 
 
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

###############################################################################
# check if new() strips additional sep chars at front/end before caching

foreach (' foo bar ','foo bar ',' foo bar')
  {
  $try = "\$x = Math::String->new('$_',";
  $try .= ' { sep => " ", start => ["foo","bar"] } ); "$x";';
  $rc = eval $try; print "# For '$try'\n" if (!ok "$rc" , 'foo bar' );
  }

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
$rc = eval $try; print "# For '$try'\n" if (!ok "$rc" , 5 );

$try = "\$x = Math::String->new('foo bar foo ',";
$try .= " { sep => ' ', start => ['foo','bar'] } ); \$x->length();";
$rc = eval $try; print "# For '$try'\n" if (!ok "$rc" , 3 );

$try = "\$x = Math::String->new('foo bar ',";
$try .= ' { sep => " ", start => ["foo","bar"] } ); "$x";';
$rc = eval $try; print "# For '$try'\n" if (!ok "$rc" , 'foo bar' );

$try = "\$x = Math::String->new('foobarfoo', ['foo','bar']); \$x->length();";
$rc = eval $try; print "# For '$try'\n" if (!ok "$rc" , 3 );

$try = "\$x = Math::String->new(''); \$x->length();";
$rc = eval $try; print "# For '$try'\n" if (!ok "$rc" , 0 );

##############################################################################
# as_number

$x = Math::String->new('abc'); 
ok (ref($x->as_number()),'Math::BigInt');

##############################################################################
# numify

$x = Math::String->new('abc'); 
ok (ref($x->numify()),''); ok ($x->numify(),731);

##############################################################################
# bzero, binf, bnan, bone

$x = Math::String->new('abc'); $x->bzero();
ok (ref($x),'Math::String'); ok ($x,''); ok ($x->sign(),'+');
$x = Math::String->new('abc'); $x->bnan();
ok (ref($x),'Math::String'); ok_undef ($x->bstr()); ok ($x->sign(),'NaN');
$x = Math::String->new('abc'); $x->binf();
ok (ref($x),'Math::String'); ok_undef ($x->bstr()); ok ($x->sign(),'+inf');

$x = Math::String::bzero(); 
ok (ref($x),'Math::String'); ok ($x,''); ok ($x->sign(),'+');
$x = Math::String::bnan();
ok (ref($x),'Math::String'); ok_undef ($x->bstr()); ok ($x->sign(),'NaN');
$x = Math::String::binf();
ok (ref($x),'Math::String'); ok_undef ($x->bstr()); ok ($x->sign(),'+inf');

$x = Math::String::bone();
ok (ref($x),'Math::String'); ok ($x->bstr(),'a'); ok ($x->sign(),'+');
$x = Math::String::bone(undef,['z'..'a']);
ok (ref($x),'Math::String'); ok ($x->bstr(),'z'); ok ($x->sign(),'+');

##############################################################################
# accuracy/precicison

ok_undef ($Math::String::accuracy);
ok_undef ($Math::String::precision);
ok ($Math::String::div_scale,0);
ok ($Math::String::round_mode,'even');

##############################################################################
# new( { str => 'aaa', num => 123 } );

$x = Math::String->new ( { str => 'aaa', num => 123 } );
ok ($x,'aaa'); ok ($x->as_number(),123); ok ($x->is_valid(),1);
# invalid matching string form is updated (not via ++, since this invalidates
# the cache, and thus syncronizes the two representations)
# This is actually a test of a mis-feature, something that shouldn't work since
# the string is invalid in the first place
$x += 'a'; ok ($x->as_number(),124); ok ($x,'dt'); 

# first/last
$x = Math::String->new('abc');
ok ($x->first(1),'a');
ok ($x->first(2),'aa');
ok ($x->last(1),'z');
ok ($x->last(2),'zz');
# -> and :: syntax
ok (Math::String->first(3),'aaa');
ok (Math::String->last(3),'zzz');
# -> and :: with different charset
ok (Math::String->last(3,[reverse 'a'..'z']),'aaa');
ok (Math::String->last(3,[reverse 'a'..'z']),'aaa');

# check error()
$x = Math::String->new ( { str => 'aaa', num => 123 } ); ok ($x->error(),'');

###############################################################################
# class()
 
$x = Math::String->new('abc');
ok ($x->class(3),26*26*26);
ok ($x->class(0),1);

###############################################################################
# copy() bug with not sharing charset (and inc)
 
my $cs = Math::String::Charset->new( {
  sets => {
   0 => ['a'..'f'],
   1 => ['a'..'f','A'..'F'],
  -1 => ['a'..'f','0'..'3','!','.','?'],
  -2 => ['a'..'f','0'..'3','!','.','?'],
   },
 
  } );
 
$x = Math::String->new('F?',$cs); 
ok (++$x,'aaa');
ok (--$x,'F?');
#$x = Math::String->new('',$cs); $x += 'F?'; 
#ok ($x,'F?');

# all done

###############################################################################
# Perl 5.005 does not like ok ($x,undef)

sub ok_undef
  {
  my $x = shift;
  $x = $x->bstr() if ref($x);

  ok (1,1) and return 1 if !defined $x;
  ok ($x,'undef');
  return 0;
  }

1;

__DATA__
abc:'0'..'9':NaN
abc:'a'..'b':NaN
abc:'a'..'c':abc:18
