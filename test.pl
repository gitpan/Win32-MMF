use strict;
use warnings;
use Win32::MMF;

# define a swap file
my $swapfile = undef;
my $namespace = 'Win32::MMF::MyString';

# fork a process
defined(my $pid = fork()) or die "Can not fork a child process!";

if ($pid) {
    # in parent
    my ($swap, $ns) = UseNamespace($namespace);

    # create a view of 100 bytes inside the namespace
    my $view = mmf_MapViewOfFile($ns, 0, 100);

    my $str = "This is a test";

    print "Write: $str\n";
    mmf_Poke($view, $str, length($str));
    
    sleep(3);

    mmf_UnmapViewOfFile($view);
    mmf_CloseHandle($ns);
    mmf_CloseHandle($swap);
} else {
    # in child
    sleep(1);   # wait for parent to finish writing

    my ($swap, $ns) = UseNamespace($namespace);

    # create a view of 100 bytes inside the namespace
    my $view = mmf_MapViewOfFile($ns, 0, 100);

    my $str = mmf_Peek($view);
    print "Read: $str\n";

    mmf_UnmapViewOfFile($view);
    mmf_CloseHandle($ns);
    mmf_CloseHandle($swap);
}



sub UseNamespace {
    my $namespace = shift;

    # attempt to use existing namespace
    my $ns = mmf_OpenFileMapping($namespace);

    # open or create swap file if namespace does not exist
    my $swap = 0;
    if (!$ns) {
        if ($swapfile) {
            # use external swap file
            $swap = mmf_OpenFile($swapfile) if -f $swapfile;
            $swap = mmf_CreateFile($swapfile) if !$swap;
        }

        # create a 1000-byte long shared memory namespace
        $ns = mmf_CreateFileMapping($swap, 1000, $namespace);
    }

    return ($swap, $ns);
}

