package Mavlink2;

use strict;
use warnings;
use IO::Socket::INET;
use IO::Select;
use Time::HiRes qw(time);
use Mavlink2::HeartBeat;
use Mavlink2::Boot;
use Mavlink2::SystemTime;
use Mavlink2::Input;
use Mavlink2::Constants;
use Exporter qw();

use constant BUFFER_SIZE => 2048;

our $VERSION = '1.00';

sub import {
    my $class = shift;

    local $Exporter::ExportLevel = 1;
    Mavlink2::Constants->import;
}

sub new {
    my ( $class, %args ) = @_;

    my $self = bless \%args, $class;
    $self->_init;

    return $self;
}

sub connect {
    my ( $self, $server ) = @_;

    if ($server) {
        unless ( $server =~ /^udp:\/\/([\w\d\-\_\.]+)(?:\:(\d+))?/ ) {
            die "Invalid Server URI";
        }

        $self->{host} = $1;
        $self->{port} = $2;
    }

    eval {
        local $| = 1;
        $self->_connect;

        my $running = 1;
        $SIG{INT} = sub { $running = undef };

        $self->_send_boot_sequence;

        while ($running) {
            my $start_time = time();

            $self->_single_step;

            # Calculate Load
            my $total_time = time() - $start_time;
            my $busy_time  = $total_time - $self->{idle_time};
            $self->{load} = int( $busy_time / $total_time * 1000 );
        }

        $self->_disconnect;

    };

    if ($@) {
        print STDERR "FATAL: $@\n";
    }

}

sub _calculate_timeout {
    my $self = shift;

    my @timeouts;
    my $ts = time();

    if ( $self->{recv_tstamp} ) {
        push @timeouts, $self->{timeout} - $ts + $self->{recv_tstamp};
    }
    else {
        push @timeouts, $self->{timeout};
    }

    if ( $self->{hb_tstamp} ) {
        push @timeouts, $self->{heartbeat_interval} - $ts + $self->{hb_tstamp};
    }
    else {
        push @timeouts, $self->{heartbeat_interval};
    }

    @timeouts = sort { $a <=> $b } @timeouts;
    return $timeouts[0];
}

sub _can_read {
    my $self = shift;

    my $start_time = time();
    my $result     = $self->{select}->can_read( $self->_calculate_timeout );
    $self->{idle_time} = time() - $start_time;

    return $result;
}

sub _connect {
    my $self = shift;

    $self->{socket} = IO::Socket::INET->new(
        PeerAddr => "$self->{host}:$self->{port}",
        Proto    => 'udp'
    ) or die "FATAL: Error in Socket Creation: $!\n";

    $self->{select} = IO::Select->new( $self->{socket} );

}

sub _connection_lost {

}

sub _disconnect {
    my $self = shift;

    $self->{socket}->close;
    $self->{socket} = undef;
}

sub _init {
    my $self = shift;

    $self->{heartbeat_interval} = 1;
    $self->{hb_tstamp}          = 0;
    $self->{recv_tstamp}        = 0;
    $self->{timeout}            = 10;
    $self->{host}               = '127.0.0.1';
    $self->{port}               = 14550;
}

sub _process_events {
    my $self = shift;

    $self->{socket}->recv( my $buffer, BUFFER_SIZE );
    my $packet = Mavlink2::Input->from($buffer);

    if ($packet) {
    }

    $self->{recv_tstamp} = time();
}

sub _single_step {
    my $self = shift;

    my $now = time();

    # heartbeats
    if ( $now - $self->{hb_tstamp} > $self->{heartbeat_interval} ) {
        $self->_send_heartbeat;
    }

    # Lost connection
    if ( $now - $self->{recv_tstamp} > $self->{timeout} ) {
        $self->_connection_lost;
    }

    if ( $self->_can_read ) {

        # Process events
        $self->_process_events;
    }

}

sub _send_heartbeat {
    my $self = shift;

    my $packet = Mavlink2::HeartBeat->new(
        $self->{system_id}, $self->{component_id},
        $self->{type},      $self->{autopilot}
    );

    $self->{socket}->send( $packet->serialize );
    $self->{hb_tstamp} = time();

}

sub _send_boot_sequence {
    my $self = shift;

    my $packet =
      Mavlink2::Boot->new( $self->{system_id}, $self->{component_id},
        int( $VERSION * 100 ) );

    $self->{socket}->send( $packet->serialize );

    $packet =
      Mavlink2::SystemTime->new( $self->{system_id}, $self->{component_id} );
    $self->{socket}->send( $packet->serialize );
}

1;
