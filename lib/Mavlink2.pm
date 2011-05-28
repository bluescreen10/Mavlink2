package Mavlink2;

use strict;
use warnings;

our $VERSION = 1.0;

use constant DEFAULT_PORT => 14550;

sub new {
    my $class = shift;
    my $self = bless { mavs => [] }, $class;
    $self->_init(@_);
    return $self;
}

sub register {
    my ( $self, $mav ) = @_;
    push @{$self->{mavs}}, $mav;
}

sub run {
    my $self = shift;

    unless (@{$self->{mavs}}) {
        die "No MAV's Registered\n";
    }

    

}


sub _init {
    my ( $self, $url ) = @_;

    unless ( $url =~ /^udp:\/\/([w.]+)(?\:(\d+))?/ ) {
        die "Invalid URL";
    }

    $self->{host} = $1;
    $self->{port} = $2 || DEFAULT_PORT;

}


1;
