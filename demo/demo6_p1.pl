use strict;
use warnings;
use Win32::MMF::Shareable qw/ Debug /;
use CGI;

Win32::MMF::Shareable::Init( -namespace => 'MySharedmem' );

# Process 1

tie my @array, "Win32::MMF::Shareable", '@array';
tie my $sigM, "Win32::MMF::Shareable", 'sigM';
tie my $sig1, "Win32::MMF::Shareable", 'sig1';
tie my $cgi, "Win32::MMF::Shareable", 'cgi';

$sig1 = 1;

while (!$sigM) {}

for (1..10) {
    push @array, $_
}

# create a shared CGI object to be used by proc 2
$cgi = new CGI;

$sig1 = 1;
