package Win32::MMF::Shareable;

require 5.00503;
use strict;
use warnings;
use Carp;
use Win32::MMF;

require Exporter;
require DynaLoader;

our @ISA = qw/ Exporter /;
our $VERSION = '0.04';

# ------------------- Tied Interface -------------------

my $ns;
my $locking_level = 0;

sub import {
    my $class = shift;
    if (@_ && !$ns) {
        $ns = Win32::MMF->new(@_) or croak "No shared mem!";
        $ns->{_autolock} = 0;
    }
}

my $default_settings = {
    _key => undef,      # only the key is used
    _type => undef,     # set data type
    _swapfile => undef, # use system pagefile
    _namespace => 'shareable',
    _size => 128 * 1024,    # 128k default size
    _iterating => '',
};

sub init_with_default_settings {
    if (!$ns) {
        $ns = Win32::MMF->new ( -namespace => $default_settings->{_namespace},
                                -size => $default_settings->{_size},
                                -swapfile => $default_settings->{_swapfile} )
                or croak "No shared mem!";
        $ns->{_autolock} = 0;
    }
}

sub namespace {
    return $ns;
}

sub lock {
    return if !$ns;
    $ns->lock() if $locking_level;
    $locking_level++;
}

sub unlock {
    return if !$ns;
    $locking_level--;
    $ns->unlock() if !$locking_level;
}

sub shlock {
    return if !$ns;
    $ns->lock() if $locking_level;
    $locking_level++;
}

sub shunlock {
    return if !$ns;
    $locking_level--;
    $ns->unlock() if !$locking_level;
}

sub debug {
    $ns && $ns->debug();
}

sub TIESCALAR {
    return _tie(S => @_);
}

sub TIEARRAY {
    return _tie(A => @_);
}

sub TIEHASH {
    return _tie(H => @_);
}

sub CLEAR {
    my $self = shift;
    $self->lock();
    $ns->setvar($self->{_key}, '');
    if ($self->{_type} eq 'A') {
        $self->{_data} = [];
    } elsif ($self->{_type} eq 'H') {
        $self->{_data} = {};
    } else {
        croak "Attempt to clear non-aggegrate";
    }
    $self->unlock();
}

sub EXTEND { }

sub STORE {
    my $self = shift;
    $self->lock();
    $self->{_data} = $ns->getvar($self->{_key});

TYPE: {
        if ($self->{_type} eq 'S') {
            $self->{_data} = shift;
            last TYPE;
        }
        if ($self->{_type} eq 'A') {
            my $i   = shift;
            my $val = shift;
            $self->{_data}->[$i] = $val;
            last TYPE;
        }
        if ($self->{_type} eq 'H') {
            my $key = shift;
            my $val = shift;
            $self->{_data}->{$key} = $val;
            last TYPE;
        }
        croak "Variables of type $self->{_type} not supported";
    }

    $ns->setvar($self->{_key}, $self->{_data}) or
        croak("Out of memory!");

    $self->unlock();

    return 1;
}

sub FETCH {
    my $self = shift;

    $self->lock();

    if ($self->{_iterating}) {
        $self->{_iterating} = ''
    } else {
        $self->{_data} = $ns->getvar($self->{_key});
    }

    my $val;
TYPE: {
        if ($self->{_type} eq 'S') {
            if (defined $self->{_data}) {
                $val = $self->{_data};
                # print "FETCH: $val\n";
                last TYPE;
            } else {
                $self->unlock();
                return;
            }
        }
        if ($self->{_type} eq 'A') {
            if (defined $self->{_data}) {
                my $i = shift;
                $val = $self->{_data}->[$i];
                last TYPE;
            } else {
                $self->unlock();
                return;
            }
        }
        if ($self->{_type} eq 'H') {
            if (defined $self->{_data}) {
                my $key = shift;
                $val = $self->{_data}->{$key};
                last TYPE;
            } else {
                $self->unlock();
                return;
            }
        }
        croak "Variables of type $self->{_type} not supported";
    }

    $self->unlock();

    return $val;
}

# ------------------------------------------------------------------------------

sub DELETE {
    my $self = shift;
    my $key  = shift;

    $self->lock();

    $self->{_data} = $ns->getvar($self->{_key}) || {};
    my $val = delete $self->{_data}->{$key};
    $ns->setvar($self->{_key}, $self->{_data});

    $self->unlock();

    return $val;
}

sub EXISTS {
    my $self = shift;
    my $key  = shift;

    $self->lock();
    $self->{_data} = $ns->getvar($self->{_key}) || {};
    $self->unlock();

    return exists $self->{_data}->{$key};
}

sub FIRSTKEY {
    my $self = shift;
    my $key  = shift;

    $self->{_iterating} = 1;

    $self->lock();
    $self->{_data} = $ns->getvar($self->{_key}) || {};

    my $reset = keys %{$self->{_data}}; # reset
    my $first = each %{$self->{_data}};

    $self->unlock();

    return $first;
}

sub NEXTKEY {
    my $self = shift;

    # caveat emptor if hash was changed by another process
    my $next = each %{$self->{_data}};

    if (not defined $next) {
        $self->{_iterating} = '';
        return undef;
    } else {
        $self->{_iterating} = 1;
        return $next;
    }
}

sub FETCHSIZE {
    my $self = shift;

    $self->lock();
    $self->{_data} = $ns->getvar($self->{_key}) || [];
    $self->unlock();

    return scalar(@{$self->{_data}});
}

sub STORESIZE {
    my $self = shift;
    my $n    = shift;

    $self->lock();
    $self->{_data} = $ns->getvar($self->{_key}) || [];
    $#{@{$self->{_data}}} = $n - 1;
    $ns->setvar($self->{_key}, $self->{_data});
    $self->unlock();

    return $n;
}

sub SHIFT {
    my $self = shift;

    $self->lock();
    $self->{_data} = $ns->getvar($self->{_key}) || [];
    my $val = shift @{$self->{_data}};
    $ns->setvar($self->{_key}, $self->{_data});
    $self->unlock();

    return $val;
}

sub UNSHIFT {
    my $self = shift;

    $self->lock();
    $self->{_data} = $ns->getvar($self->{_key}) || [];
    my $val = unshift @{$self->{_data}} => @_;
    $ns->setvar($self->{_key}, $self->{_data});
    $self->unlock();

    return $val;
}

sub SPLICE {
    my($self, $off, $n, @av) = @_;

    $self->lock();
    $self->{_data} = $ns->getvar($self->{_key}) || [];
    my @val = splice @{$self->{_data}}, $off, $n => @av;
    $ns->setvar($self->{_key}, $self->{_data});
    $self->unlock();

    return @val;
}

sub PUSH {
    my $self = shift;

    $self->lock();

    $self->{_data} = $ns->getvar($self->{_key});

    if (!defined $self->{_data}) {
        $self->{_data} = [];
    }
    push @{$self->{_data}}, @_;

    $ns->setvar($self->{_key}, $self->{_data}) or
        croak "Not enough shared memory";

    $self->unlock();
}

sub POP {
    my $self = shift;

    $self->lock();
    $self->{_data} = $ns->getvar($self->{_key}) || [];
    my $val = pop @{$self->{_data}};
    $ns->setvar($self->{_key}, $self->{_data});
    $self->unlock();

    return $val;
}

sub UNTIE {
    my $self = shift;

    $self->lock();
    $ns->deletevar($self->{_key}, undef);
    $self->unlock();
}


# ------------------------------------------------------------------------------

sub _tie {
    my $type  = shift;
    my $class = shift;

    my $self = { %$default_settings };
    $self->{_type} = $type;

    # allowed parameters are aliases to IPC::Shareable
    my $allowed_parameters = "key";

    if (ref $_[0] eq 'HASH') {
        # Parameters passed in as HASHREF
        for my $p (keys %{$_[0]}) {
            $self->{'_' . lc $p} = $_[0]->{$p};
        }
    } elsif ($_[0] =~ /^-(?=$allowed_parameters)/i) {
        # Parameters passed in as named parameters
        my %p = @_;
        for my $p (keys %p) {
            $self->{'_' . lc substr($p,1)} = $p{$p};
        }
    } else {
        # Parameters passed in as: tie $variable, 'Win32::MMF::Shareable', 'data', \%options
        $self->{_key} = shift;
        # Parameters passed in as HASHREF
        for my $p (keys %{$_[1]}) {
            $self->{'_' . lc $p} = $_[0]->{$p};
        }
    }

    croak "The label/key for the tied variable must be defined!" if !$self->{_key};

    init_with_default_settings() if ! $ns;

    $ns->lock();
    $ns->setvar($self->{_key}, '') if !$ns->findvar($self->{_key});
    $ns->unlock();

    bless $self, $class;
}

1;

