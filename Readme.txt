#######################################################################
#
# Win32::MMF - Win32 Memory Mapped File Support for Perl
# Version: 0.01 (06 Feb 2004)
# 
# Author: Roger Lee <roger@cpan.org>
#
# $Id: Readme.txt,v 1.1 2004/02/05 15:04:16 Roger Lee Exp $
#
#######################################################################

This module provides Windows' native Memory Mapped File Service
for inter-process or intra-process communication under Windows.

The current version of Win32::MMF is available on CPAN at:

  http://search.cpan.org/search?query=Win32::MMF

The following is a list of the functions implemented in this module:

  $debugmode = GetDebugMode();		# 0 - off, 1 - on
  SetDebugMode($debugmode);

  $fh = CreateFile($filename);		# Create new swap file
  $fh = OpenFile($filename);		# Open existing swap file
  CloseHandle($fh);				    # Close openned swap file handle

  $ns = CreateFileMapping($filehandle, $filesize, $namespace);
  $ns = OpenFileMapping($namespace);	# Use existing namespace
  CloseHandle($ns);				        # Close openned namespace

  $var = MapViewOfFile($ns, $offset, $size)	# Create a view inside the namespace
  UnmapViewOfFile($var);			        # Delete the view

  Poke($var, $str, length($str));		# Store a string into view
  $str = Peek($var);			        # Retrieve a string from the view

  PokeIV($var, $i);				        # Store a number(long) into view
  $i = PeekIV($var);			        # Retrieve a number from the view

  # High-level Namespace Functions

  # claim a swapfile to use as namespace (default size is 64k)
  # if $swapfile is undef, will use system page file instead

  ($swp, $ns) = ClaimNamespace($swapfile, $namespace [, $size]);

  ReleaseNamespace($swp, $namespace);

  $ns = UseNamespace($namespace);  # use existing namespace


Full documentation is available in POD format inside MMF.pm.

This is the first release of the module and the functionality is limited.
But it will not stay that way for long as I will add more functionality soon.

Enjoy. ;-)

