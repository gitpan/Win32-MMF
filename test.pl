use strict;
use warnings;
use Win32::MMF;

my $swapfile = undef;  # use Windows system swap file
my $namespace = 'MyMMF.MyString';

# fork a process
defined(my $pid = fork()) or die "Can not fork a child process!";

if ($pid) {
    # in parent
    
    # claim a namespace of default 64K size
    my ($swap, $ns) = ClaimNamespace($swapfile, $namespace);

    # create a view of 100 bytes inside the namespace
    my $view = MapViewOfFile($ns, 0, 100);

    my $str = "This is a test";

    print "Write: $str\n";
    Poke($view, $str, length($str));

    sleep(3);

    UnmapViewOfFile($view);
    ReleaseNamespace($swap, $ns);
} else {
    # in child

    sleep(1);   # wait for parent to finish writing

    # use an existing namespace
    my $ns = UseNamespace($namespace) or die "Namespace $namespace not found";

    # create a view of 100 bytes inside the namespace
    my $view = MapViewOfFile($ns, 0, 100);

    my $str = Peek($view);
    print "Read: $str\n";

    UnmapViewOfFile($view);
    ReleaseNamespace(undef, $ns);
}

