#! /usr/bin/perl

use strict;
use Win32::MMF::Shareable;

my %share;
my $ns = tie( %share, 'Win32::MMF::Shareable', 'share' ) || die;

$|++;

my $delay = 0.01;
my $i = 0;

if( fork )
{
  select( undef, undef, undef, $delay / 2 );
  while( $i < 20 )
  {
    $share{ 'P' . $i++ } = '-';
    $ns->lock();
    print "parent($i): " . join( '', values( %share ) ) . "\n";
    $ns->unlock();
    select( undef, undef, undef, $delay );
  }
}
else
{
  while( $i < 20 )
  {
  	$share{ 'P' . $i++ } = '#';
  	$ns->lock();
    print "child($i) : " . join( '', values( %share ) ) . "\n";
    $ns->unlock();
    select( undef, undef, undef, $delay );
  }
}


