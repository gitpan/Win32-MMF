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
        _reuse     => 0,           # reuse existing namespace only
        _autolock  => 1,           # I/O locking by default
        _swap      => 0,           # swap file handle
        _ns        => 0,           # namespace handle
        _view      => 0,           # view handle
        _timeout   => 10,          # default timeout value
        _semaphore => 0,           # semaphore used for locking
    };

    croak "Namespace must be defined!" if !defined $_[1];
    
    my $allowed_parameters = "namespace|size|swapfile|reuse|autolock|timeout";

    if (ref $_[1] eq 'HASH') {
        # Parameters passed in as HASHREF
        for my $p (keys %{$_[1]}) {
            croak "Unknown parameter '$p', must be [$allowed_parameters]\n"
                if $p !~ /^(?:$allowed_parameters)$/i;
            $self->{'_' . lc $p} = $_[1]->{$p};
        }
    } elsif ($_[1] =~ /^-(?=$allowed_parameters)/i) {
        # Parameters passed in as named parameters
        my (undef, %p) = @_;
        for my $p (keys %p) {
            croak "Unknown parameter '$p', must be [$allowed_parameters]\n"
                if $p !~ /^-(?:$allowed_parameters)$/i;
            $self->{'_' . lc substr($p,1)} = $p{$p};
        }
    } else {
        # Parameters passed in as normal
        (undef, $self->{_namespace}, $self->{_size}, $self->{_swapfile}, $self->{_reuse})
            = @_;
    }

    croak "Namespace must be defined!" if !$self->{_namespace};

    # use or open or create namespace
    if ($self->{_reuse}) {
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
    my $str;

    if ($self->{_autolock}) {
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
 my $ns1 = Win32::MMF->new ( -namespace => "My.Var1" );

 $ns1->write($data);

 # --- in process 2 ---
 my $ns2 = Win32::MMF->new ( -namespace => "My.Var1",
                             -reuse     => 1 )
         or die "namespace not exist";

 $data = $ns2->read();


=head1 ABSTRACT

This module provides Windows' native Memory Mapped File Service
for shared memory support under Windows. The core of the module
is written in XS and is currently supported only under Windows
NT/2000/XP.

The current version 0.04 of Win32::MMF is available on CPAN at:

  http://search.cpan.org/search?query=Win32::MMF


=head1 DESCRIPTION

=head2 Programming Style

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

Note that there is no need to explicitly unmap the view, close the
namespace and close the swap file in object-oriented mode, the view,
namespace and swap file handles are automatically closed-off and
disposed of when the Win32::MMF object falls out of scope.


=head1 REFERENCE

=head2 Memory Mapped File (MMF) Under Windows

Under Windows, code and data are both repesented by pages of memory
backed by files on disk - code by executable image an data by system
pagefile (swapfile). These are called memory mapped files. Memory
mapped files can be used to provide a mechanism for shared memory
between processes. Different processes are able to share data backed
by the same swapfile, whether it's the system pagefile or a
user-defined swapfile.

Windows has a tight security system that prevents processes from
directly sharing information among each other, but mapped memory files
provide a mechanism that works with the Windows security system - by
using a name that all processes use to open the swapfile.

A shared section of the swapfile is translated into pages of memory
that are addressable by more than one process, Windows uses a system
resource called a prototype page table entry (PPTE) to enable more
than one process to address the same physical page of memory, thus
multiple process can share the same data without violating the Windows
system security.

In short, MMF's provide shared memory under Windows.


=head2 What is a Namespace?

In Win32::MMF a namespace represents shared memory identified by a
unique name. The namespace must be unique system wide. A suggested
convention to follow is <[APPID].[VARID]>.

Example: 'MyApp.SharedMem1'.


=head2 Creating a Namespace Object

There are three ways to pass parameters into the Win32::MMF
object constructor: named parameters, a hashref of parameters
or a list of parameters.

=over 4

=item Using Named Parameters

 $ns = Win32::MMF->new(
              -swapfile => $swapfilename,
              -namespace => $namespace_id,
              -size => 1024,
              -reuse => 0,
              -autolock => 1,
              -timeout => 10 );

The parameter names begin with '-' and are case
insensitive. For example, -swapfile, -Swapfile
and -SwapFile are equivalent.

=item Passing Parameters in a Hashref

 $ns = Win32::MMF->new({
              swapfile => $swapfilename,
              namespace => $namespace_id,
              size => 1024,
              reuse => 0 });

The parameter names do not begin with '-' and
are case insensitive. This mode is good for working
with external configuration files.

=item Passing Parameters in a List

 $ns = Win32::MMF->new(
              $namespace_id,
              $size,
              $swapfile,
              $reuse_flag);

The I<$namespace_id> parameter is mandatory, other
parameters are optional.

=item Input Parameters

=over 4

=item -swapfile

Specify the name of the memory mapped file (swap file).
if it is omitted or undef then the system swap file will
be used.

=item -namespace

A string that uniquely identifies a block of shared memory.
The namespace must be unique system wide. A suggested
convention to follow is <[APPID].[VARID]>. This option is
mandatory.

=item -size

Specify the size of the memory mapped file in bytes.

=item -reuse

This option tells the constructor to check if the namespace
has already been declared by another process, and use the
existing namespace instead. It gurrantees that a namespace
is not created if it does not exist.

=item -autolock

Automatic read/write locking, turned on by default.

=item -timeout

Specify the number of seconds to wait before timing out
the lock. This value is set to 10 seconds by default. Set
timeout to 0 to wait forever.

=back

=back


=head2 Lock a Namespace Object (for Read/Write Access)

All read and write accesses to a namespace are locked
by default. However if auto-locking is turned off, a
namespace can be explicitly locked with the B<lock> method.

$ns->lock($timeout);

=over 4

=item Input Parameters

=over 4

=item $timeout

Number of seconds before the lock attempt fails.

=back

=item Return Values

 undef    Namespace error
 0        Time out waiting for lock
 1        Success

=back


=head2 Unlock A Namespace Object

$ns->unlock();


=head2 Accessing a Namespace

All read and write accesses to a namespace are locked
by default to preserve data integrity across processes.
The excellent L<Data::Serializer> module is used for
data serialization.

=over 4

=item $ns->write($data, ...);

Serialize all given data and then write the serialized
data into namespace. Please refer to the L<Data::Serializer>
documentation on how to serialize and retrieve data.

A string is written into the shared memory in Pascal
string format, ie., <length><string data>. Special care
is taken to preserve the string during transportation
so that the exact string including '\0' characters will
be retrieved back from the shared memory.

=item $ns->write_iv($i);

Writes an integer value into the shared memory. This can
be used to clear the length of a string (and thus clearing
the shared memory).

=item $data = $ns->read();

Retrieves the serialized data string from the shared memory,
and deserializes back into perl variable(s). Please refer to
the L<Data::Serializer> documentation on how to serialize and
retrieve data.

=item $i = $ns->read_iv();

Reads an integer value from the shared memory. This can
be used to test the shared memory for availability of data,
for example.

=back

=back


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
     sleep(1);  # child process wait for parent to initialize

     my $ns1 = Win32::MMF->new ( -namespace => "My.data1",
                                 -reuse => 1 )
             or die "Namespace does not exist!";

     my $ns2 = Win32::MMF->new ( -namespace => "My.data2",
                                 -reuse => 1 )
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


=head1 SEE ALSO

L<Data::Serializer>

=head1 CREDITS

Credits go to my wife Jenny and son Albert, and I love them forever.

=back


=head1 AUTHOR

Roger Lee <roger@cpan.org>

=back


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004 Roger Lee

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

