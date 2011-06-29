package Mavlink2::SystemTime;

use strict;
use warnings;
use Mavlink2::Constants;
use base qw(Mavlink2::Common);
use Time::HiRes qw(time);

sub new {
    my ( $class, $system_id, $component_id ) = @_;

    bless {
        system_id    => $system_id,
        component_id => $component_id,
    }, $class;
}

sub serialize {
    my $self = shift;

    $self->_build_packet(
        $self->{system_id}, $self->{component_id},
        $self->id_for_class(__PACKAGE__),
        pack( 'Q', int( time() * 1_000_000 ) )
    );
}

sub deserialize {
    die "system_time\n";
}

1;
