# drop in replacement for IPC::Shareable on Windows platform
use strict;

# ----------------------------------------------------------------
# code to switch between Win32::MMF::Shareable and IPC::Shareable
# automatically on different platforms
# ----------------------------------------------------------------
use vars qw/ $Shareable /;
BEGIN {
    $Shareable = ($^O eq 'MSWin32') ? 'Win32::MMF::Shareable'
                                    : 'IPC::Shareable';
    eval "require $Shareable";
    if ($^O eq 'MSWin32') {
        Win32::MMF::Shareable::Init( -namespace => 'MySharedmem' );
    }
}
# ----------------------------------------------------------------

my $glue = 'data';
my %options = (
    create    => 0,
    exclusive => 0,
    mode      => 0644,
    destroy   => 0,
    );
my %colours;
tie %colours, $Shareable, $glue, { %options } or
    die "client: tie failed\n";
foreach my $c (keys %colours) {
    print "client: these are $c: ",
        join(', ', @{$colours{$c}}), "\n";
}
delete $colours{'red'};
exit;
