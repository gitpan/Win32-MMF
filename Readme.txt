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

  $debugmode = mmf_GetDebugMode();		# 0 - off, 1 - on
  mmf_SetDebugMode($debugmode);

  $fh = mmf_CreateFile($filename);		# Create new swap file
  $fh = mmf_OpenFile($filename);		# Open existing swap file
  mmf_CloseHandle($fh);				# Close openned swap file handle

  $ns = mmf_CreateFileMapping($filehandle, $filesize, $namespace);
  $ns = mmf_OpenFileMapping($namespace);	# Use existing namespace
  mmf_CloseHandle($ns);				# Close openned namespace

  $var = mmf_MapViewOfFile($ns, $offset, $size)	# Create a view inside the namespace
  mmf_UnmapViewOfFile($var);			# Delete the view

  mmf_Poke($var, $str, length($str));		# Store a string into view
  $str = mmf_Peek($var);			# Retrieve a string from the view

  mmf_PokeIV($var, $i);				# Store a number(long) into view
  $i = mmf_PeekIV($var);			# Retrieve a number from the view


Full documentation is available in POD format inside MMF.pm.

This is the first release of the module and the functionality is limited.
But it will not stay that way for long as I will add more functionality soon.

Enjoy. ;-)
