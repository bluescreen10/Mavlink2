package Mavlink2::Boot;

use strict;
use warnings;
use Mavlink2::Constants;
use base qw(Mavlink2::Common);

sub new {
    my ( $class, $system_id, $component_id, $version ) = @_;

    bless {
        system_id    => $system_id,
        component_id => $component_id,
        version      => $version
    }, $class;
}

sub serialize {
    my $self = shift;

    $self->_build_packet(
        $self->{system_id}, $self->{component_id},
        $self->id_for_class(__PACKAGE__),
        pack( 'CCCC', $self->{version} )
    );
}

sub deserialize {
    die "why\n";
}

1;
