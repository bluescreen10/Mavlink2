package Mavlink2::SetSystemMode;

use strict;
use warnings;
use Mavlink2::Constants;
use Mouse;

extends 'Mavlink2::Common';

has system_id    => ( is => 'ro' );
has component_id => ( is => 'ro' );
has target       => ( is => 'ro' );
has mode         => ( is => 'ro' );

sub deserialize {
    my ( $class, $packet ) = @_;
    my @values = ( unpack( "C*", $packet ) )[ 2, 3, 5, 6 ];

    $class->new(
        system_id    => $values[0],
        component_id => $values[1],
        target       => $values[2],
        mode         => $values[3],
    );
}

sub serialize {
    my $self = shift;

    $self->_build_packet(
        $self->{system_id}, $self->{component_id},
        $self->id_for_class(__PACKAGE__),
        pack( 'CC', $self->{target}, $self->{mode} )
    );
}

1;
