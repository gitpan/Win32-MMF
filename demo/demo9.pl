use strict;
use Data::Dumper;
use Win32::MMF::Shareable;

my $ns = tie my $ref, 'Win32::MMF::Shareable', '$ref';
tie my $alias, 'Win32::MMF::Shareable', '$ref';

# limitation as hash reference
$ref = { a => 1, b => 2, c => 3 };
$alias->{d} = 4;
print Dumper($ref);

# limitation as list reference
$ref = [ qw( a b c d e f g h ) ];
push @$ref, 'i';
print Dumper($alias);

$ns->debug();

# clear works
$ref = ();
$ns->debug();

