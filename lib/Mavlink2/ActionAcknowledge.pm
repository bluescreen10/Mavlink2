package Mavlink2::ActionAcknowledge;

use strict;
use warnings;
use Mavlink2::Constants;
use base qw(Mavlink2::Common);

sub new {
    my ( $class, $system_id, $component_id, $action, $result ) = @_;

    bless {
        system_id    => $system_id,
        component_id => $component_id,
        action       => $action,
        result       => $result
    }, $class;

}

sub deserialize {
    my ( $class, $packet ) = @_;
}

sub serialize {
    my $self = shift;

    $self->_build_packet(
        $self->{system_id}, $self->{component_id},
        $self->id_for_class(__PACKAGE__),
        pack( 'C*', $self->{action}, $self->{result} )
    );
}

1;
