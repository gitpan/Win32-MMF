use strict;
use warnings;
use Win32::MMF;
use Data::Dumper;

my $ns = new Win32::MMF( -namespace => "MyNamespace" ) or die;

# setting variables and getting them back
my $var1 = "Hello world!";
my $var2 = {
    'Name' => 'Roger',
    'Module' => 'Win32::MMF',
};

$ns->setvar('Hello', $var1);
$ns->setvar('Hash', $var2);
$ns->debug();

my $r1 = $ns->getvar('Hello');
my $r2 = $ns->getvar('Hash');
print Dumper($r1), Dumper($r2), "\n";

$ns->deletevar('Hello');
$ns->setvar('Hash', undef);
$ns->debug();

# variable memory management within MMF
$ns->setvar("Var1", "X" x 100);
$ns->setvar("Var2", "X" x 100);
$ns->debug();

$ns->setvar("MyMMF.Var1", '');
$ns->debug();

$ns->setvar("MyMMF.Var1", 'X' x 150);
$ns->debug();

$ns->deletevar("MyMMF.Var1");
$ns->debug();

$ns->setvar("MyMMF.Var2", "X" x 150);
$ns->debug();

$ns->setvar("MyMMF.Var2", undef);
$ns->debug();


