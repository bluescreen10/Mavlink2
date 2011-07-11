package Mavlink2::Action;

use strict;
use warnings;
use Mavlink2::Constants;
use base qw(Mavlink2::Common);
use Class::Accessor qw(antlers);

sub new {
    my ( $class, $system_id, $component_id, $action ) = @_;

    bless {
        system_id    => $system_id,
        component_id => $component_id,
        action       => $action
    }, $class;

}

sub deserialize {
    my ( $class, $packet ) = @_;

    my ( $system_id, $component_id, $action ) =
      ( unpack( "C*", $packet ) )[ 5, 6, 7 ];
    $class->new( $system_id, $component_id, $action );
}

sub action {
    my $self = shift;
    return $self->{action};
}

sub is_for {
    my ( $self, $system_id, $component_id ) = @_;

    return $self->{system_id} == $system_id
      and $self->{component_id} == $component_id;
}

sub serialize {
    my $self = shift;

    $self->_build_packet(
        $self->{system_id}, $self->{component_id},
        $self->id_for_class(__PACKAGE__),
        pack( 'C', $self->{action} )
    );
}

1;
