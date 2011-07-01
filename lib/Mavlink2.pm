package Mavlink2;

use strict;
use warnings;
use IO::Socket::INET;
use IO::Select;
use Time::HiRes qw(time);
use Mavlink2::HeartBeat;
use Mavlink2::Boot;
use Mavlink2::SystemTime;
use Mavlink2::SystemStatus;
use Mavlink2::Input;
use Mavlink2::Constants;
use Exporter qw();
use Class::Accessor qw(antlers);

has load            => ( is => 'rw' );
has battery_level   => ( is => 'rw' );
has battery_voltage => ( is => 'rw' );
has system_id       => ( is => 'r' );
has component_id    => ( is => 'r' );
has type            => ( is => 'r' );
has autopilot       => ( is => 'r' );
has system_mode     => ( is => 'rw' );
has navigation_mode => ( is => 'rw' );
has general_status  => ( is => 'rw' );
has handler_for     => ( is => 'r' );
has is_connected    => ( is => 'r' );

use constant {
    BUFFER_SIZE        => 2048,
    MAX_TIMEOUT        => 500,
    HEARTBEAT_INTERVAL => 1,
    STATUS_INTERVAL    => 5,
};

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
        $SIG{INT} = sub { print "SIGINT\n"; $running = undef };

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

sub schedule {
    my ( $self, $interval, $code_ref ) = @_;

    $interval = int($interval);

    unless ( $interval && ref $code_ref eq 'CODE' ) {
        warn 'Can\'t schedule an invalid task';
    }

    $self->{scheduled_tasks}->{ +$code_ref } = {
        last     => 0,
        interval => $interval,
        code_ref => $code_ref
    };

}

sub _calculate_timeout {
    my $self = shift;

    my $timeout = MAX_TIMEOUT;

    while ( my ( $id, $task ) = each %{ $self->{scheduled_tasks} } ) {
        my $now = time();

        my $task_timeout = $task->{interval};

        # Was executed at least once
        if ( $task->{last} ) {
            $task_timeout = $task->{interval} - $now + $task->{last};
        }

        $timeout = $task_timeout if ( $task_timeout < $timeout );
    }

    return $timeout;
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

=head2 _init

Intialize Client with default values

=cut

sub _init {
    my $self = shift;

    $self->{status_interval} = 60;
    $self->{status_tstamp}   = 0;

    $self->{recv_tstamp}     = 0;
    $self->{timeout}         = 10;
    $self->{host}            = '127.0.0.1';
    $self->{port}            = 14550;
    $self->{battery_voltage} = 0;
    $self->{battery_level}   = 1000;
    $self->{load}            = 0;
    $self->{system_mode}     = MAV_MODE_READY;
    $self->{navigation_mode} = MAV_NAV_GROUNDED;
    $self->{general_status}  = MAV_STATE_BOOT;
    $self->{handler_for}     = {};

    $self->_init_scheduler;

}

sub _init_scheduler {
    my $self = shift;

    $self->schedule( HEARTBEAT_INTERVAL, sub { $self->_send_heartbeat } );

}

sub _call_handler {
    my ( $self, $handler ) = @_;

    if ( exists $self->{handler_for}->{$handler} ) {
        my $method = $self->{handler_for}->{$handler};

        eval { &$method() };

        if ($@) {
            print STDERR "Call to '$handler' failed: $@\n";
            $self->{general_status} = MAV_STATE_CRITICAL;
            return 0;
        }
    }

    return 1;
}

sub _call_on_connect_handler {
    my $self = shift;
    if ( $self->_call_handler('on_connect') ) {
        $self->schedule( STATUS_INTERVAL, sub { $self->_send_status } );
    }
}

sub _call_on_start_handler {
    my $self = shift;
    if ( $self->_call_handler('on_start') ) {
        $self->{general_status} = MAV_STATE_STANDBY;
    }
}

sub _process_events {
    my $self = shift;

    $self->{socket}->recv( my $buffer, BUFFER_SIZE );
    my $packet = Mavlink2::Input->from($buffer);

    if ($packet) {
        if ( $packet->isa('Mavlink2::HeartBeat') and not $self->{is_connected} )
        {
            $self->{is_connected} = 1;
            $self->_call_on_connect_handler;
        }
    }

    $self->{recv_tstamp} = time();
}

sub _run_scheduled_tasks {
    my $self = shift;

    while ( my ( $id, $task ) = each %{ $self->{scheduled_tasks} } ) {
        my $now = time();

        if ( $now - $task->{last} > $task->{interval} ) {
            if ( &{ $task->{code_ref} }() ) {
                $task->{last} = $now;
            }
            else {
                delete $self->{scheduled_tasks}->{$id};
            }

        }

    }

}

sub _single_step {
    my $self = shift;

    $self->_run_scheduled_tasks;

    if ( $self->_can_read ) {

        # Process events
        $self->_process_events;
    }

}

sub _send_heartbeat {
    my $self = shift;

    $self->{socket}->send(
        Mavlink2::HeartBeat->new(
            $self->{system_id}, $self->{component_id},
            $self->{type},      $self->{autopilot}
          )->serialize
    );

    return 1;
}

sub _send_boot_sequence {
    my $self = shift;

    my $packet =
      Mavlink2::Boot->new( $self->{system_id}, $self->{component_id},
        int( $VERSION * 100 ) );

    $self->{socket}->send( $packet->serialize );

    $self->_send_status;
    $self->_call_on_start_handler;
    $self->_send_status;

}

sub _send_status {
    my $self = shift;

    $self->{socket}->send(
        Mavlink2::SystemStatus->new(
            system_id       => $self->{system_id},
            component_id    => $self->{component_id},
            system_mode     => $self->{system_mode},
            navigation_mode => $self->{navigation_mode},
            general_status  => $self->{general_status},
            load            => $self->{load},
            battery_voltage => $self->{battery_voltage},
            battery_level   => $self->{battery_level}
          )->serialize
    );

    return 1;
}

sub _send_system_time {
    my $self = shift;

    $self->{socket}->send(
        Mavlink2::SystemTime->new( $self->{system_id}, $self->{component_id} )
          ->serialize );

}

1;
