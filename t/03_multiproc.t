use strict;
use warnings;
use Test::More tests => 2;

BEGIN {
    use_ok( 'Win32::MMF::Shareable' );
}

defined ( my $pid = fork() ) or die "Can not create a child process";

if ($pid != 0) {
    tie my $s, 'Win32::MMF::Shareable', 'scalar';
    tie my $t, 'Win32::MMF::Shareable', 'sig';

    while (!$t) {};

    is( $s, 'Hello world', 'Multi-process sharedmem OK' );
} else {
    tie my $s, 'Win32::MMF::Shareable', 'scalar';
    tie my $t, 'Win32::MMF::Shareable', 'sig';

    $s = 'Hello world';
    $t = 1;
    
    exit(0);
}

