#######################################################################
#
# Win32::MMF - Win32 Memory Mapped File Support for Perl
# Version: 0.03 (06 Feb 2004)
# 
# Author: Roger Lee <roger@cpan.org>
#
# $Id: Readme.txt,v 1.2 2004/02/06 15:44:19 Roger Lee Exp $
#
#######################################################################

This module provides Windows' native Memory Mapped File Service
for inter-process or intra-process communication under Windows.

The current version of Win32::MMF is available on CPAN at:

  http://search.cpan.org/search?query=Win32::MMF

The following is a quick overview of the look and feel of the module:

  use Win32::MMF;
  
  # --- in process 1 ---
  my $ns1 = Win32::MMF->new( -namespace => "MyData1" );

  $ns1->write($data);   # autolock by default

  # --- in process 2 ---
  my $ns2 = Win32::MMF->new( -namespace => "MyData1", -nocreate => 1 )
          or die "namespace not exist";

  $data = $ns2->read(); # autolock by default


Full documentation is available in POD format inside MMF.pm.

This is the first release of the module and the functionality is limited.
But it will not stay that way for long as I will add more functionality soon.

Enjoy. ;-)

