use strict;
use warnings;
use Test::More tests => 1;
use Win32::MMF::Shareable;

$|++;

if( fork )  # parent
{
  tie( my @share, 'Win32::MMF::Shareable', 'share' ) || die;
  tie( my $sig, 'Win32::MMF::Shareable', 'sig' ) || die;
  while (!$sig) {};
  push @share, 'parent';
  sleep 2;
}
else        # child
{
  tie( my @share, 'Win32::MMF::Shareable', 'share' ) || die;
  tie( my $sig, 'Win32::MMF::Shareable', 'sig' ) || die;
  $sig = 1;
  sleep 1;
  push @share, 'child';
  is(scalar @share, 2, "Shared array OK");
}
