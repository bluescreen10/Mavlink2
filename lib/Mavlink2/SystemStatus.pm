package Mavlink2::SystemStatus;

use strict;
use warnings;
use Mavlink2::Constants;
use Mavlink2::Input;
use base qw(Mavlink2::Common);
use Time::HiRes qw(time);

sub new {
    my ( $class, %args ) = @_;
    bless \%args, $class;
}

sub serialize {
    my $self = shift;

    $self->_build_packet(
        $self->{system_id},
        $self->{component_id},
        $self->id_for_class(__PACKAGE__),
        pack( 'CCCnnnn',
            $self->{system_mode},     $self->{navigation_mode},
            $self->{general_status},  $self->{load},
            $self->{battery_voltage}, $self->{battery_level},
            Mavlink2::Input->packet_drop_count )
    );
}

sub deserialize {
    die "system_time\n";
}

1;
