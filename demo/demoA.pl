#! /usr/bin/perl

use strict;
use Win32::MMF::Shareable;

$|++;

my $delay = 0.01;
my $i = 0;

if( fork )
{
  my %share;
  my $ns = tie( %share, 'Win32::MMF::Shareable', 'share' ) || die;
  print $ns->namespace()->{_view}, "\n";

  select( undef, undef, undef, $delay / 2 );
  while( $i < 20 )
  {
    $ns->lock();
    $share{ 'P' . $i++ } = '-';
    print "parent($i): " . join( '', values( %share ) ) . "\n";
    $ns->unlock();
    select( undef, undef, undef, $delay );
  }
}
else
{
  my %share;
  my $ns = tie( %share, 'Win32::MMF::Shareable', 'share' ) || die;
  print $ns->namespace()->{_view}, "\n";

  while( $i < 20 )
  {
  	$ns->lock();
  	$share{ 'P' . $i++ } = '#';
    print "child($i) : " . join( '', values( %share ) ) . "\n";
    $ns->unlock();
    select( undef, undef, undef, $delay );
  }
}


