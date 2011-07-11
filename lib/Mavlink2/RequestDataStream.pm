package Mavlink2::RequestDataStream;

use strict;
use warnings;
use Mavlink2::Constants;
use Mouse;

extends 'Mavlink2::Common';

has system_id           => ( is => 'ro' );
has component_id        => ( is => 'ro' );
has target_system_id    => ( is => 'ro' );
has target_component_id => ( is => 'ro' );
has stream_id           => ( is => 'ro' );
has stream_rate         => ( is => 'ro' );
has is_required         => ( is => 'ro' );

sub deserialize {
    my ( $class, $packet ) = @_;
    my @values = ( unpack( "CCCCCCCCnC", $packet ) )[ 2, 3, 5, 6, 7, 8, 9, 10 ];

    $class->new(
        system_id           => $values[0],
        component_id        => $values[1],
        target_system_id    => $values[2],
        target_component_id => $values[3],
        stream_id           => $values[4],
        stream_rate         => $values[5],
        is_required         => $values[6]
    );
}

sub is_for {
    my ( $self, $system_id, $component_id ) = @_;
    return $self->{target_system_id} == $system_id
      and $self->{target_component_id} == $component_id;
}

sub serialize {
    my $self = shift;

    $self->_build_packet(
        $self->{system_id},
        $self->{component_id},
        $self->id_for_class(__PACKAGE__),
        pack( 'CCCnC',
            $self->{target_system_id}, $self->{target_component_id},
            $self->{stream_id},        $self->{stream_rate},
            $self->{is_required} )
    );
}

1;
