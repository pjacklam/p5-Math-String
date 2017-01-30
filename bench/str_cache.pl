#!/usr/bin/perl -w

# benchmark to show the difference with and without caching in Math::String:
# v1.16 w/o cache, v1.20 w/ cache

$| = 1;
use lib '../lib';
use Math::String;
use strict;
use Benchmark;

my $a = Math::String->new('');

my ($x,$i); $i = 0; 

my $c = 0.1; 	# correction factor if benchmark is to slow/fast

timethese ( $c*10000, { 
  'inc' => sub { $a++; $x = "$a"; },
  'dec' => sub { $a--; $x = "$a"; }, 
  });

$a = Math::String->new('', Math::String::Charset->new ( {
  sep => '-', start => [ 'foo', 'bar', 'baz' ],
  } ) );

timethese ( $c*10000, { 
  'inc w/ sep' => sub { $a++; $x = "$a"; },
  'dec w/ sep' => sub { $a--; $x = "$a"; }, 
  });

$a = 'a';

timethese ( $c*10000000, { 
  'build-in ++' => sub { $a++; $x = "$a"; },
  'build-in --' => sub { $a--; $x = "$a"; }, 
  });

exit;

timethese ( $c*800, { 
  'new,bstr' => sub { $a = Math::String->new('a'.'a' x int($i)); $x = "$a"; $i += 0.01; },
  } );

$a = Math::String->new('a'.'a' x 200);
# correct for faster bench if cache is present
my $f = 1; $f = 200 if defined $a->{_cache}->{str};	
timethese ( $f*$c*200, { 
  'bstr' => sub { $x = "$a"; },
  } );

my $y = Math::BigInt->new(3);
$i = 100;

timethese ( $c*200, { 
  'no bstr' => sub { $x = Math::String->new('a'.'a' x $i); 
    $x = ($x * $y + $x + $x ** $y) / $y; },
  } );

