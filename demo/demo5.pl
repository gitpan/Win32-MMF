use strict;
use warnings;
use Win32::MMF::Shareable;

# Signaling with tied shared variables

Win32::MMF::Shareable::Init( -namespace => 'MySharedmem' );

defined(my $pid = fork()) or die "Can not fork a child process!";

if (!$pid) {
    tie my $sig1, "Win32::MMF::Shareable", '$signal1';
    tie my $sig2, "Win32::MMF::Shareable", '$signal2';

    print "PROC1 WAIT SIGNAL 2\n";
    while (!$sig2) {};
    print "PROC1 SEND SIGNAL 1\n";

    $sig1 = 1;
} else {
    tie my $sig1, "Win32::MMF::Shareable", '$signal1';
    tie my $sig2, "Win32::MMF::Shareable", '$signal2';

    print "PROC2 SEND SIGNAL 2\n";
    $sig2 = 1;
    print "PROC2 WAIT SIGNAL 1\n";
    while (!$sig1) {};

    print "PROC2 GOT SIGNAL 1\n";
}
