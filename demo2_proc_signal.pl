use strict;
use warnings;
use Win32::MMF;
use Data::Dumper;
use CGI;

# fork a process
defined(my $pid = fork()) or die "Can not fork a child process!";

if ($pid) {
   my $ns1 = Win32::MMF->new ( -namespace => "MyMMF",
                               -size => 1024 * 1024 );

   my $cgi = new CGI;
   my $hash = {a=>[1,2,3], b=>4, c=>"A\0B\0C\0"};
   my $str = "Hello World!";

   $ns1->setvar("MyMMF.HASH", $hash);
   $ns1->setvar("MyMMF.CGI", $cgi);
   $ns1->setvar("MyMMF.STRING", $str);

   print "--- PROC1 - Sent ---\n";
   print Dumper($hash), "\n";
   print Dumper($cgi), "\n";
   print Dumper($str), "\n";

   # signal proc 2
   $ns1->setvar("MyMMF.SIG", '');

   # wait for ACK variable to come alive
   do {} while ! $ns1->findvar("MyMMF.ACK");
   $ns1->deletevar("MyMMF.ACK");

   # debug current MMF structure
   $ns1->debug();

} else {

   my $ns1 = Win32::MMF->new ( -namespace => "MyMMF",
                               -size => 1024 * 1024 );

   do {} while !$ns1->findvar("MyMMF.SIG");
   $ns1->deletevar("MyMMF.SIG");

   my $hash = $ns1->getvar("MyMMF.HASH");
   my $cgi = $ns1->getvar("MyMMF.CGI");
   my $str = $ns1->getvar("MyMMF.STRING");

   print "--- PROC2 - Received ---\n";
   print Dumper($hash), "\n";
   print Dumper($cgi), "\n";

   print "--- PROC2 - Use Received Object ---\n";
   # use the object from another process :-)
   print $cgi->header(),
         $cgi->start_html(), "\n",
         $cgi->end_html(), "\n\n";

   # signal proc 1
   $ns1->setvar("MyMMF.ACK", '');
}
