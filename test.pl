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
