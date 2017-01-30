#!/usr/bin/perl -w

use Test;
use strict;

BEGIN
  {
  $| = 1;
  unshift @INC, '../lib'; # to run manually
  # chdir 't' if -d 't';
  plan tests => 137;
  }

use Math::String::Charset;

$Math::String::Charset::die_on_error = 0;	# we better catch them

###############################################################################
# study

my $words = [ 'test', 'toast', 'froesche', 'taste', 'fast' ];
my $hash = Math::String::Charset::study ( order => 2, words => $words);

ok ($hash->{start}->[0],'t');
ok ($hash->{start}->[1],'f');
ok ($hash->{end}->[0],'t');
ok ($hash->{end}->[1],'e');
ok ($hash->{bi}->{t}->[0],'e');
ok ($hash->{bi}->{t}->[1],'a');
ok ($hash->{bi}->{t}->[2],'o');

###############################################################################
# simple charset's

my $a = Math::String::Charset->new( ['a'..'z'] );

ok ($a->error(),"");

my $ok = 0;
my $aa = [ 'a'..'z' ];
my @ab = $a->start();

for (my $i = 0; $i < @$aa; $i++)
  {
  $ok ++ if $aa->[$i] ne $ab[$i];
  }
ok ($ok,0);

ok ($a->length(),26);

$a = Math::String::Charset->new( ['a'..'c'] );
ok ($a->error(),"");
ok ($a->length(),3);

ok ($a->class(),3);
ok ($a->class(2),3*3);
ok ($a->class(3),3*3*3);
ok ($a->class(4),3*3*3*3);

ok ($a->first(),'');
ok ($a->last(),'');

ok ($a->first(1),'a');
ok ($a->last(1),'c');

ok ($a->first(2),'aa');
ok ($a->last(2),'cc');

ok ($a->first(3),'aaa');
ok ($a->last(3),'ccc');

ok ($a->lowest(1),1);
ok ($a->lowest(2),1+3);
ok ($a->lowest(3),1+3+3*3);
ok ($a->lowest(4),1+3+3*3+3*3*3);

ok ($a->highest(1),3);
ok ($a->highest(2),3+3*3);
ok ($a->highest(3),3+3*3+3*3*3);
ok ($a->highest(4),3+3*3+3*3*3+3*3*3*3);

ok ($a->str2num(''),0);
ok ($a->str2num('a'),1);
ok ($a->str2num('aa'),1+3);
ok ($a->str2num('aaa'),1+3+3*3);
ok ($a->str2num('cba'),1+2*3+3*3*3);

ok ($a->num2str(0),'');
ok ($a->num2str(1),'a');
ok ($a->num2str(2),'b');
ok ($a->num2str(3),'c');

ok ($a->num2str(1+2),'c');
ok ($a->num2str(1+3),'aa');
ok ($a->num2str(1+3+2*3+2),'cc');
ok ($a->num2str(1+3+3*3),'aaa');
ok ($a->num2str(1+3+2*3*3),'baa');
ok ($a->num2str(1+2*3+3*3*3),'cba');

# is valid
ok_undef ($a->{_sep});
ok ($a->is_valid('abcbca'),1);
ok_undef ($a->is_valid('abcxbca'));
ok ($a->is_valid('a'),1);

# char()
ok ($a->char(0),'a');
ok ($a->char(1),'b');
ok ($a->char(-1),'c');
ok_undef ($a->char(3));

# check charlength
$a = Math::String::Charset->new( ['a','b','foo','c'] );
if ($a->error() !~ /Illegal.*char.*length.*not/)
  {
  ok ($a->error(),"not '" . $a->error() . "'"); 
  }
else
  {
  ok (1,1);
  }

$a = Math::String::Charset->new( ['foo','bar','baz'] );
ok ($a->error(),'');
ok ($a->char(0),'foo');
ok ($a->char(1),'bar');
ok ($a->char(-1),'baz');

ok ($a->num2str(1),'foo');
ok ($a->num2str(2),'bar');
ok ($a->num2str(3),'baz');
ok ($a->num2str(3+1),'foofoo');

ok ($a->str2num('foo'),1);
ok ($a->str2num('foofoo'),1+3);
ok ($a->str2num('foobaz'),1+3+2);
ok ($a->str2num('barfoo'),1+3+3);

ok ($a->is_valid('barfoo'),1);
ok ($a->is_valid('barfoobar'),1);
ok_undef ($a->is_valid('barfotbar'));
ok ($a->is_valid('bar'),1);
ok ($a->is_valid(''),1);
ok_undef ($a->is_valid('fuh'));

###############################################################################
# simple charset's with sep char

ok_undef ($a->{_sep});
$a = Math::String::Charset->new( { start => ['hans','mag','blumen'],
   sep => ' ',} );
ok ($a->{_sep},' ');
ok ($a->{_order},1);
ok ($a->num2str(3+1),'hans hans');

ok ($a->str2num('hans hans'),3+1);
ok ($a->str2num('hans hans hans'),3+3*3+1);
ok ($a->str2num('hans mag blumen'),3+3*3+6);

# front/end stripping
ok ($a->str2num(' hans mag blumen'),3+3*3+6);
ok ($a->str2num('hans mag blumen '),3+3*3+6);
ok ($a->str2num(' hans mag blumen '),3+3*3+6);

$a = Math::String::Charset->new( { start => ['foooo','bar','buuh'], 
  sep => ' ',} );
ok ($a->error(),"");

ok ($a->is_valid('foooo bar buuh'),1);
ok_undef ($a->is_valid('fooo bar buuh'));
ok ($a->is_valid(' foooo bar buuh bar buuh '),1);

$a = Math::String::Charset->new( { start => ['foo','bar'], sep => '',} );
ok ($a->error(),"Field 'sep' must not be empty");

###############################################################################
# bi grams

$a = Math::String::Charset->new( { 
    start => ['b','c','a'], 
    bi => {
      'a' => [ 'b', 'c', 'a' ],
      'b' => [ 'c', 'b' ],
      'c' => [ 'a', 'c' ]
      }
  } );
ok ($a->error(),"");
ok ($a->length(),3);
ok (scalar $a->end(),3);

$ok = 0;
$aa = [ 'b','c','a' ];
@ab = $a->start();

for (my $i = 0; $i < @$aa; $i++)
  {
  $ok ++ if $aa->[$i] ne $ab[$i];
  }
ok ($ok,0);

ok ($a->class(1),3); 		# b,c,a
ok ($a->class(2),7); 		# bc
				# bb
				# ca
				# cc
				# ab
				# ac
				# aa
ok ($a->class(3),3*2+2*2+2*3); 	# 7 combos:
		 		# 3 of them end in c => 3 * 2 
                       		# 2 of them end in b => 2 * 2 
                       		# 2 of them end in a => 2 * 3
				# sum:			16
				# result:
				# bca
				# bcc
				# bbc
				# bbb
				# cab
				# cac
				# caa
				# cca
				# ccc
				# abc
				# abb
				# aca
				# acc
				# aab
				# aac
				# aaa
ok ($a->class(4),5*3+7*2+4*2); 	# 16 combos:
				# 5 times a: 5 * 3
				# 7 times c: 7 * 2
				# 4 times b: 4 * 2
				# sum:       37

ok ($a->str2num(''),0);
ok ($a->str2num('b'),1);
ok ($a->str2num('c'),2);
ok ($a->str2num('a'),3);

# check sum of strings starting with a certain string
$a->_calc(4);

ok ($a->{_scnt}->[1]->{a},1);
ok ($a->{_scnt}->[1]->{c},1);
ok ($a->{_scnt}->[1]->{b},1);

ok ($a->{_scnt}->[2]->{a},3);
ok ($a->{_scnt}->[2]->{b},2);
ok ($a->{_scnt}->[2]->{c},2);

ok ($a->{_scnt}->[3]->{a},7);
ok ($a->{_scnt}->[3]->{b},4);
ok ($a->{_scnt}->[3]->{c},5);

ok ($a->{_scnt}->[4]->{a},16);
ok ($a->{_scnt}->[4]->{b},9);
ok ($a->{_scnt}->[4]->{c},12);

ok ($a->{_ssum}->[1]->{b},0);
ok ($a->{_ssum}->[1]->{c},1);
ok ($a->{_ssum}->[1]->{a},2);

ok ($a->{_ssum}->[2]->{b},0);
ok ($a->{_ssum}->[2]->{c},2);
ok ($a->{_ssum}->[2]->{a},4);

ok ($a->{_ssum}->[3]->{b},0);
ok ($a->{_ssum}->[3]->{c},4);
ok ($a->{_ssum}->[3]->{a},9);

ok ($a->{_ssum}->[4]->{b},0);
ok ($a->{_ssum}->[4]->{c},9);
ok ($a->{_ssum}->[4]->{a},21);

###############################################################################
# restricting ending chars

$a = Math::String::Charset->new( { 
    start => ['b','c','a'], 
    bi => {
      'a' => [ 'b', 'c', 'a' ],
      'b' => [ 'c', 'b' ],
      'c' => [ 'a', 'c' ],
      'q' => [ ],
      }
  } );
ok ($a->error(),"");
ok ($a->length(),3);		# a,b,c
ok (scalar $a->end(),4);	# a,b,c,q

$a = Math::String::Charset->new( { 
    start => ['b','c','a'], 
    bi => {
      'a' => [ 'b', 'c', 'a' ],
      'b' => [ 'c', 'b' ],
      'c' => [ 'a', 'c', 'x' ],
      'q' => [ ],
      },
    end => [ 'a', 'b' ],
  } );

ok ($a->error(),"");
ok ($a->length(),2);		# a,b
ok (scalar $a->end(),4);	# a,b,q,x

# check sum of strings starting with a certain string
$a->_calc(4);

ok ($a->{_scnt}->[1]->{a},1);
ok_undef ($a->{_scnt}->[1]->{c});
ok ($a->{_scnt}->[1]->{b},1);

ok ($a->{_scnt}->[2]->{a},2);	# ab, aa 	(ac is invalid)
ok ($a->{_scnt}->[2]->{b},1);	# bb 		(bc is invalid)
ok ($a->{_scnt}->[2]->{c},2);	# ca, cx	(cc is invalid)

###############################################################################
# Perl 5.005 does not like ok ($x,undef)

sub ok_undef
  {
  my $x = shift;

  ok (1,1) and return if !defined $x;
  ok ($x,'undef');
  }


