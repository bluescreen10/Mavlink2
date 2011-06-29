package Mavlink2::HeartBeat;

use strict;
use warnings;
use Mavlink2::Constants;
use base qw(Mavlink2::Common);

sub new {
    my ( $class, $system_id, $component_id, $type, $autopilot ) = @_;

    bless {
        system_id    => $system_id,
        component_id => $component_id,
        type         => $type,
        autopilot    => $autopilot
    }, $class;

}

sub deserialize {
    my ( $class, $packet ) = @_;
    my ( $system_id, $component_id, $type, $autopilot ) =
      ( unpack( "C*", $packet ) )[ 3, 4, 6, 7 ];
    $class->new($system_id,$component_id,$type,$autopilot);
}

sub serialize {
    my $self = shift;

    $self->_build_packet(
        $self->{system_id},
        $self->{component_id},
        $self->id_for_class(__PACKAGE__),
        pack( 'C*', $self->{type}, $self->{autopilot}, MAVLINK_VERSION )
    );
}


1;
