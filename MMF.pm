package Win32::MMF;

require 5.00503;
use strict;
use warnings;

require Exporter;
require DynaLoader;

our @ISA = qw/ Exporter DynaLoader /;

our @EXPORT = qw/
        GetDebugMode SetDebugMode
        CreateFile OpenFile CloseHandle
        CreateFileMapping OpenFileMapping
        MapViewOfFile UnmapViewOfFile
        Peek Poke PeekIV PokeIV
        ClaimNamespace ReleaseNamespace UseNamespace
    /;

our @EXPORT_OK = @EXPORT;
our $VERSION = '0.01';

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


1;

=pod

=head1 NAME

Win32::MMF - Win32 Memory Mapped File (MMF) Support for Perl

=head1 SYNOPSIS

  use Win32::MMF;

  $debugmode = GetDebugMode();		# 0 - off, 1 - on
  SetDebugMode($debugmode);

  $fh = CreateFile($filename);		# Create new swap file
  $fh = OpenFile($filename);		# Open existing swap file
  CloseHandle($fh);				    # Close openned swap file handle

  $ns = CreateFileMapping($fh, $filesize, $namespace);
  $ns = OpenFileMapping($namespace);	# Use existing namespace
  CloseHandle($ns);				        # Close openned namespace

  $var = MapViewOfFile($ns, $offset, $size)	# Create a view inside the namespace
  UnmapViewOfFile($var);			        # Delete the view

  Poke($var, $str, length($str));	# Store a string into view
  $str = Peek($var);			    # Retrieve a string from the view

  PokeIV($var, $i);				    # Store a number(long) into view
  $i = PeekIV($var);			    # Retrieve a number from the view

  # High-level Namespace Functions

  # claim a swapfile to use as namespace
  ($swp, $ns) = ClaimNamespace($swapfile, $namespace [, $size]);

  ReleaseNamespace($swp, $namespace);

  $ns = UseNamespace($namespace);  # use existing namespace


=head1 ABSTRACT

This module provides Windows' native Memory Mapped File Service
for inter-process or intra-process communication under Windows.
The module is written in XS and is currently supported only under
Windows NT/2000/XP.

The current version of Win32::MMF is available on CPAN at:

  http://search.cpan.org/search?query=Win32::MMF


=head1 CREDITS

All the credits go to my beloved wife Jenny and son Albert,
and I love them forever.


=head1 DESCRIPTION

  use strict;
  use warnings;
  use Win32::MMF;

  # define a swap file
  my $swapfile = undef;
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

=head1 AUTHOR

Roger Lee <roger@cpan.org>

=cut

