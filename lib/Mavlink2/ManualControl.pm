package Mavlink2::ManualControl;

use strict;
use warnings;
use Mavlink2::Constants;
use Mouse;

extends 'Mavlink2::Common';

has system_id        => ( is => 'ro' );
has component_id     => ( is => 'ro' );
has target           => ( is => 'ro' );
has roll             => ( is => 'ro' );
has pitch            => ( is => 'ro' );
has yaw              => ( is => 'ro' );
has thrust           => ( is => 'ro' );
has is_roll_manual   => ( is => 'ro' );
has is_pitch_manual  => ( is => 'ro' );
has is_yaw_manual    => ( is => 'ro' );
has is_thrust_manual => ( is => 'ro' );

sub deserialize {
    my ( $class, $packet ) = @_;
    my @values =
      ( unpack( "CCCCCCf>f>f>f>CCCC", $packet ) )
      [ 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13 ];

    print "roll:$values[3] pitch:$values[4] yaw:$values[5] thrust: $values[6]\n";

    $class->new(
        system_id        => $values[0],
        component_id     => $values[1],
        target           => $values[2],
        roll             => $values[3],
        pitch            => $values[4],
        yaw              => $values[5],
        thrust           => $values[6],
        is_roll_manual   => $values[7],
        is_pitch_manual  => $values[8],
        is_yaw_manual    => $values[9],
        is_thrust_manual => $values[10],
    );
}

sub serialize {
    my $self = shift;

    $self->_build_packet(
        $self->{system_id},
        $self->{component_id},
        $self->id_for_class(__PACKAGE__),
        pack( 'CC',
            $self->{target},          $self->{roll},
            $self->{pitch},           $self->{yaw},
            $self->{thrust},          $self->{is_roll_manual},
            $self->{is_pitch_manual}, $self->{is_yaw_manual},
            $self->{is_thrust_manual} )
    );
}

1;
