package Mavlink2::Vehicle;

use strict;
use warnings;

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    $self->_init(@_);
    return $self;
}

sub _init {
    my ( $self, $system_id, $component_id ) = @_;
    $self->{system_id} = $system_id;
    $self->{component_id} = $component_id;
}

sub system_id {
    my $self = shift;
    if (@_) {
        $self->{system_id} = shift;
    }
    return $self->{system_id};
}

sub component_id {
    my $self = shift;
    if (@_) {
        $self->{component_id} = shift;
    }
    return $self->{component_id};
}

1;
