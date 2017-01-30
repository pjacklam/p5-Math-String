#!/usr/bin/perl -w

# for Math::String::Charset::Wordlist.pm

use Test;
use strict;

BEGIN
  {
  $| = 1;
  unshift @INC, '../lib'; # to run manually
  chdir 't' if -d 't';
  plan tests => 28;
  }

use Math::String::Charset::Wordlist;
use Math::String;

$Math::String::Charset::die_on_error = 0;	# we better catch them
my $a;

my $c = 'Math::String::Charset::Wordlist';

###############################################################################
# creating via Math::String::Charset

$a = Math::String::Charset->new( { type => 2, order => 1,
  file => 'testlist.lst' } );
ok ($a->error(),"");
ok (ref($a),$c);
ok ($a->isa('Math::String::Charset'));

# create directly
$a = $c->new( { file => 'testlist.lst' } );
ok ($a->error(),"");
ok (ref($a),$c);
ok ($a->isa('Math::String::Charset'));

###############################################################################
# dictionary tests

#1 math
#2 test
#3 string
#4 unsorted
#5 wordlist
#6 dictionary

ok ($a->first(1), 'math');
ok ($a->num2str(0), '');
ok ($a->num2str(1),'math');
ok ($a->num2str(2),'test');
ok ($a->num2str(3),'string');
ok ($a->num2str(4),'unsorted');
ok ($a->num2str(5),'wordlist');
ok ($a->num2str(6),'dictionary');

# num2str in list mode
my @a = $a->num2str(1);
ok ($a[0],'math');
ok ($a[1],1);		# one word is one "character"


ok ($a->length(),6);
ok ($a->count(1),6);

ok ($a->str2num('math'),1);
ok ($a->str2num('test'),2);
ok ($a->str2num('string'),3);
ok ($a->str2num('unsorted'),4);
ok ($a->str2num('wordlist'),5);
ok ($a->str2num('dictionary'),6);

#########################
# needs newer Tie::File!
#ok ($a->offset(0),0);
#ok ($a->offset(1),5);

# test caching and next()/prev()

my $x = Math::String->new('unsorted',$a);
$x++;
ok ($x - Math::BigInt->new(5), '');
ok ($x,'wordlist');
$x--;
ok ($x - Math::BigInt->new(4), '');
ok ($x,'unsorted');

###############################################################################
# Perl 5.005 does not like ok ($x,undef)

sub ok_undef
  {
  my $x = shift;

  ok (1,1) and return if !defined $x;
  ok ($x,'undef');
  }


