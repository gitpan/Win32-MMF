use strict;
use warnings;
use Test::More tests => 1;

$|++;

if( fork )  # parent
{
  require Win32::MMF::Shareable;
  tie( my @share, 'Win32::MMF::Shareable', 'share' ) || die;
  tie( my $sig, 'Win32::MMF::Shareable', 'sig' ) || die;
  while (!$sig) {};
  push @share, 'parent';
  sleep 2;
}
else        # child
{
  require Win32::MMF::Shareable;
  tie( my @share, 'Win32::MMF::Shareable', 'share' ) || die;
  tie( my $sig, 'Win32::MMF::Shareable', 'sig' ) || die;
  $sig = 1;
  sleep 1;
  push @share, 'child';
  is(scalar @share, 2, "Shared array OK");
}

unlink "C:/private.swp";
