package Win32::MMF;

require 5.00503;
use strict;
use warnings;
use Carp;
use Data::Serializer;

require Exporter;
require DynaLoader;

our @ISA = qw/ Exporter DynaLoader /;

our @EXPORT_OK = qw/
        GetDebugMode SetDebugMode
        CreateFile OpenFile CloseHandle
        CreateFileMapping OpenFileMapping
        MapViewOfFile UnmapViewOfFile
        Peek Poke PeekIV PokeIV
        ClaimNamespace ReleaseNamespace UseNamespace
        CreateSemaphore WaitForSingleObject ReleaseSemaphore
    /;

our $VERSION = '0.03';
our $TRANSPORTER = Data::Serializer->new (
                        serializer => 'Data::Dumper',
                        portable   => '1',
                        compress   => '0',
                        serializer_token => '1',
                        options  => {} )
        or croak("No suitable data transporter found");


bootstrap Win32::MMF $VERSION;


# High-level Name Space Wrapper Functions


# Sytax: ($swp, $ns) = UseNamespace($swapfile, $namespace);
sub ClaimNamespace {
    my ($swapfile, $namespace, $size) = @_;
    $size = 64 * 1024 if !$size;    # namespace 64K by default

    # attempt to use existing namespace
    my $ns = OpenFileMapping($namespace);

    # open or create swap file if namespace does not exist
    my $swap = 0;
    if (!$ns) {
        if ($swapfile) {
            # use external swap file
            $swap = OpenFile($swapfile) if -f $swapfile;
            $swap = CreateFile($swapfile) if !$swap;
            croak "Can not create swapfile: $!" if !$swap;
        }

        # create a 1000-byte long shared memory namespace
        $ns = CreateFileMapping($swap, $size, $namespace);
    }

    return ($swap, $ns);
}


# Syntax: ReleaseNamespace($swp, $ns);
sub ReleaseNamespace {
    my ($swp, $ns) = @_;
    CloseHandle($ns) if $ns;
    CloseHandle($swp) if $swp;
}


# Test for existance of a Namespace
sub UseNamespace {
    my $namespace = shift;

    # attempt to use existing namespace
    my $ns = OpenFileMapping($namespace);

    return ($ns);
}


# ------------------- Object Oriented Interface -------------------

sub new
{
    my $class = ref($_[0]) || $_[0] || "Win32::MMF";
    @_ > 1 or croak "Usage: new $class (\$namespace[, \$size[, \$swapfile]])\n";

    my $self = {
        _namespace => undef,
        _size      => 64 * 1024,   # 64k namespace by default
        _swapfile  => undef,       # use windows virtual memory
        _nocreate  => 0,           # do not create namespace if does not exist
        _autolock  => 1,           # I/O locking by default
        _swap      => 0,           # swap file handle
        _ns        => 0,           # namespace handle
        _view      => 0,           # view handle
        _timeout   => 10,          # default timeout value
        _semaphore => 0,           # semaphore used for locking
    };

    croak "Namespace must be defined!" if !defined $_[1];

    if (ref $_[1] eq 'HASH') {
        # Parameters passed in as HASHREF
        for my $p (keys %{$_[1]}) {
            croak "Unknown parameter '$p', must be [namespace|size|swapfile|nocreate|autolock|timeout]\n"
                if $p !~ /^(?:namespace|size|swapfile|nocreate|autolock|timeout)$/i;
            $self->{'_' . lc $p} = $_[1]->{$p};
        }
    } elsif ($_[1] =~ /^-(?=namespace|size|swapfile|nocreate|autolock|timeout)/i) {
        # Parameters passed in as named parameters
        my (undef, %p) = @_;
        for my $p (keys %p) {
            croak "Unknown parameter '$p', must be [namespace|size|swapfile|nocreate|autolock|timeout]\n"
                if $p !~ /^-(?:namespace|size|swapfile|nocreate|autolock|timeout)$/i;
            $self->{'_' . lc substr($p,1)} = $p{$p};
        }
    } else {
        # Parameters passed in as normal
        (undef, $self->{_namespace}, $self->{_size}, $self->{_swapfile}, $self->{_nocreate})
            = @_;
    }

    croak "Namespace must be defined!" if !$self->{_namespace};

    # use or open or create namespace
    if ($self->{_nocreate}) {
        $self->{_ns} = UseNamespace($self->{_namespace}) or return undef;
    } else {
        ($self->{_swap}, $self->{_ns}) =
            ClaimNamespace($self->{_swapfile}, $self->{_namespace}, $self->{_size});
    }

    # set default view to the namespace
    $self->{_view} = MapViewOfFile($self->{_ns}, 0, $self->{_size});

    # create semaphore object for the view
    $self->{_semaphore} = CreateSemaphore(1, 1, $self->{_namespace} . '.lock')
        or croak("Can not create semaphore!");

    bless $self, $class;
}


sub DESTROY {
    my $self = shift;

    # release existing lock if any
    CloseHandle($self->{_semaphore}) if $self->{_semaphore};

    # unmap existing views
    for my $view_id (keys %{$self->{_views}}) {
        UnmapViewOfFile($self->{_views}{$view_id}{view});
    }

    # close namespace and swap file
    ReleaseNamespace($self->{_swap}, $self->{_ns});
}


sub lock
{
    my ($self, $timeout) = @_;
    $timeout = $self->{_timeout} if !$timeout;

    return WaitForSingleObject($self->{_semaphore}, $timeout);
}


sub unlock
{
    my $self = shift;
    return ReleaseSemaphore($self->{_semaphore}, 1);
}


sub read
{
    my $self = shift;
    my $lock;
    my $str;

    if ($self->{_autolock}) {
        $lock = $self->{_lock};
        $self->lock($self->{_timeout});
        $str = Peek($self->{_view});
        $self->unlock();
    } else {
        $str = Peek($self->{_view});
    }

    return $TRANSPORTER->deserialize($str);
}


sub write
{
    my $self = shift;
    my $str = $TRANSPORTER->serialize(@_);

    if ($self->{_autolock}) {
        $self->lock($self->{_timeout});
        Poke($self->{_view}, $str, length($str));
        $self->unlock();
    } else {
        Poke($self->{_view}, $str, length($str));
    }
}


sub read_iv
{
    my $self = shift;
    return PeekIV($self->{_view});
}


sub write_iv
{
    my ($self, $value) = @_;
    PokeIV($self->{_view}, $value);
}


1;

=pod

=head1 NAME

 Win32::MMF - Win32 Memory Mapped File (MMF) Support for Perl

=head1 SYNOPSIS

 use Win32::MMF;

 # --- in process 1 ---
 my $ns1 = Win32::MMF->new ( -namespace => "MyData1" );

 $ns1->lock();
 $ns1->write($data);
 $ns1->unlock();

 # --- in process 2 ---
 my $ns2 = Win32::MMF->new ( -namespace => "MyData1",
                             -nocreate  => 1 )
         or die "namespace not exist";

 $data = $ns2->read();


=head1 ABSTRACT

This module provides Windows' native Memory Mapped File Service
for shared memory support under Windows. The core of the module
is written in XS and is currently supported only under Windows
NT/2000/XP.

The current version 0.03 of B<Win32::IPC> is available on CPAN at:

  http://search.cpan.org/search?query=Win32::MMF


=head1 DESCRIPTION

=head2 PROGRAMMING STYLE

This module provides two types of interfaces - an object-oriented
and a functional interface. The default access method is via objects.
The functional interface is not exported by default because it
requires a detailed knowledge of the Windows operating system
internals to use properly.

There are many advantages of using the object oriented interface.
For example, the following is the amount of code required in
function-oriented style to create a namespace (a named block of
shared memory). It involves openning or creating a swap file,
creating a memory mapping and finally creating a view:

   use Win32::MMF qw/ ClaimNamespace UseNamespace MapViewOfFile /;

   my ($swap, $ns, $view) = (0, 0, 0);
   $ns = UseNamespace("MyData1");
   if (!ns) {
       ($swap, $ns) = ClaimNamespace("data.swp", "MyData1", 1000);
       die "Can not create swap file" if !$swap;
       die "Can not create namespace" if !$ns;
   }

   $view = MapViewOfFile($ns, 0, 1000);

   ...

   UnmapViewOfFile($view);
   ReleaseNamespace($swap, $ns);

The following is the amount of code required to achieve the same
result in object-oriented style:

   use Win32::MMF;

   my $ns = Win32::MMF->new( -swapfile=>"data.swp",
                             -namespace=>"MyData1",
                             -size=>1000 )
       or die "Can not create shared namespace";

Note that there is no need to explicitly unmap the view and close
the swap file in object-oriented mode, the view, namespace and
swap file handles are automatically closed-off and disposed of when
the object falls out of scope.


=head2 CREATING A NEW NAMESPACE

   The parameter names are case insensitive. For example, -swapfile,
   -Swapfile and -SwapFile are equivalent. 0 or undef is returned if
   the constructor fails.

   # named parameters
   $ns = Win32::MMF->new(
              -swapfile => $swapfilename,
              -namespace => $namespace_id,
              -size => 1024,
              -nocreate => 0,
              -autolock => 1,
              -timeout => 10,
         );

   # hashref of parameters
   $ns = Win32::MMF->new(
            { swapfile => $swapfilename,
              namespace => $namespace_id,
              size => 1024,
              nocreate => 0 }
         );

   # list of parameters
   $ns = Win32::MMF->new($namespace_id, 1024, $swapfile, 0);

=item -swapfile

   Specify the name of the swap file. if it is omitted or undef
   then the system swap file will be used.

=item -namespace

   A unique string value that identifies a namespace in the
   memory mapped file. This option is mandatory.

=item -size

   Specify the size of the namespace in bytes.

=item -nocreate

   Do not create a new swap file if the swap file does not
   exist, return undef instead. Check if the namespace has
   already been declared by another process, and use the
   existing namespace instead.
   
=item -autolock

   Automatic read/write locking, turned on by default.

=item -timeout

   Specify the number of seconds to wait before timing out
   the lock. This value is set to 10 seconds by default. Set
   timeout to 0 to wait forever.


=head2 LOCKING A NAMESPACE EXPLICITLY

   $ns->lock($timeout);

=item $timeout

   Number of seconds before the lock attempt fails.


=head2 UNLOCKING A NAMESPACE EXPLICITLY

   $ns->unlock();


=head2 WRITING TO A NAMESPACE

   $ns->write($data);
   $ns->write_iv(1000);
   
=head2 READING FROM A NAMESPACE

   $data = $ns->read();
   $i    = $ns->read_iv();


=head1 EXAMPLE

   use strict;
   use warnings;
   use Win32::MMF;
   use Data::Dumper;
   use CGI;   # for testing of inter-process object transportation

   # fork a process
   defined(my $pid = fork()) or die "Can not fork a child process!";

   if ($pid) {
       my $ns1 = Win32::MMF->new ( -namespace => "My.data1" );
       my $ns2 = Win32::MMF->new ( -namespace => "My.data2" );

       my $cgi = new CGI;
       my $data = {a=>[1,2,3], b=>4, c=>"A\0B\0C\0"};

       $ns1->write($data);
       $ns2->write($cgi);

       print "--- Sent ---\n";
       print Dumper($data), "\n";
       print Dumper($cgi), "\n";

       sleep(1);

   } else {

       # in child
       sleep(1);
       my $ns1 = Win32::MMF->new ( -namespace => "My.data1",
                                   -nocreate => 1 )
               or die "Namespace does not exist!";

       my $ns2 = Win32::MMF->new ( -namespace => "My.data2",
                                   -nocreate => 1 )
               or die "Namespace does not exist!";

       my $data = $ns1->read();
       my $cgi = $ns2->read();

       print "--- Received ---\n";
       print Dumper($data), "\n";
       print Dumper($cgi), "\n";

       print "--- Use Received Object ---\n";
       # use the object from another process :-)
       print $cgi->header(),
             $cgi->start_html(), "\n",
             $cgi->end_html(), "\n";
}


=head1 CREDITS

All the credits go to my wife Jenny and son Albert, and I love them forever.


=head1 AUTHOR

Roger Lee <roger@cpan.org>

=cut

