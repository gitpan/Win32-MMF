#! /usr/bin/perl

use strict;
use Win32::MMF::Shareable;

$|++;

my $delay = 0.01;
my $i = 0;

if( fork )
{
  my @share;
  my $ns = tie( @share, 'Win32::MMF::Shareable', 'share' ) || die;
  print $ns->namespace()->{_view}, "\n";

  select( undef, undef, undef, $delay / 2 );
  while( $i < 20 )
  {
    $share[$i++] = '-';
    $ns->lock();
    print "parent($i): " . join( '', @share ) . "\n";
    $ns->unlock();
    select( undef, undef, undef, $delay );
  }
}
else
{
  my @share;
  my $ns = tie( @share, 'Win32::MMF::Shareable', 'share' ) || die;
  print $ns->namespace()->{_view}, "\n";

  while( $i < 20 )
  {
  	$share[$i++] = '#';
  	$ns->lock();
    print "child($i) : " . join( '', @share ) . "\n";
    $ns->unlock();
    select( undef, undef, undef, $delay );
  }
}


