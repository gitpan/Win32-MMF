package Win32::MMF;

require 5.00503;
use strict;
use warnings;

require Exporter;
require DynaLoader;

our @ISA = qw/ Exporter DynaLoader /;

our @EXPORT = qw/
        mmf_GetDebugMode mmf_SetDebugMode
        mmf_CreateFile mmf_OpenFile mmf_CloseHandle
        mmf_CreateFileMapping mmf_OpenFileMapping
        mmf_MapViewOfFile mmf_UnmapViewOfFile
        mmf_Peek mmf_Poke mmf_PeekIV mmf_PokeIV
    /;

our @EXPORT_OK = @EXPORT;
our $VERSION = '0.01';

bootstrap Win32::MMF $VERSION;

1;

=pod

=head1 NAME

Win32::MMF - Win32 Memory Mapped File (MMF) Support for Perl

=head1 SYNOPSIS

  use Win32::MMF;

  $debugmode = mmf_GetDebugMode();		# 0 - off, 1 - on
  mmf_SetDebugMode($debugmode);

  $fh = mmf_CreateFile($filename);		# Create new swap file
  $fh = mmf_OpenFile($filename);		# Open existing swap file
  mmf_CloseHandle($fh);				    # Close openned swap file handle

  $ns = mmf_CreateFileMapping($fh, $filesize, $namespace);
  $ns = mmf_OpenFileMapping($namespace);	# Use existing namespace
  mmf_CloseHandle($ns);				        # Close openned namespace

  $var = mmf_MapViewOfFile($ns, $offset, $size)	# Create a view inside the namespace
  mmf_UnmapViewOfFile($var);			        # Delete the view

  mmf_Poke($var, $str, length($str));	# Store a string into view
  $str = mmf_Peek($var);			    # Retrieve a string from the view

  mmf_PokeIV($var, $i);				    # Store a number(long) into view
  $i = mmf_PeekIV($var);			    # Retrieve a number from the view


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

=head1 AUTHOR

Roger Lee <roger@cpan.org>

=cut

