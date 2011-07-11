package Mavlink2;

our $VERSION = '1.00';

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
use Mavlink2::Action;
use Mavlink2::ActionAcknowledge;
use Mavlink2::Constants;
use Mavlink2::RequestDataStream;
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
    BUFFER_SIZE      => 2048,
    MAX_TIMEOUT      => 500,
    DEFAULT_INTERVAL => 1,
    LOAD_SAMPLES     => 10,
};

my %action_handler_for = (
    0  => 'on_action_hold',
    1  => 'on_action_start_motors',
    2  => 'on_action_launch',
    3  => 'on_action_return',
    4  => 'on_action_emergency_land',
    5  => 'on_action_emergency_kill',
    6  => 'on_action_confirm_kill',
    7  => 'on_action_continue',
    8  => 'on_action_motors_stop',
    9  => 'on_action_halt',
    10 => 'on_action_shutdown',
    11 => 'on_action_reboot',
    12 => 'on_action_set_manual',
    13 => 'on_action_set_auto',
    14 => 'on_action_storage_read',
    15 => 'on_action_storage_write',
    16 => 'on_action_calibrate_rc',
    17 => 'on_action_calibrate_gyroscope',
    18 => 'on_action_calibrate_magnetometer',
    19 => 'on_action_calibrate_accelerometer',
    20 => 'on_action_calibrate_pressure',
    21 => 'on_action_recorder_start',
    22 => 'on_action_recorder_pause',
    23 => 'on_action_recorder_stop',
    24 => 'on_action_take_off',
    25 => 'on_action_navigate',
    26 => 'on_action_land',
    27 => 'on_action_lotier',
    28 => 'on_action_set_origin',
    29 => 'on_action_relay_on',
    30 => 'on_action_relay_off',
    31 => 'on_action_get_image',
    32 => 'on_action_video_start',
    33 => 'on_action_video_stop',
    34 => 'on_action_reset_map',
    35 => 'on_action_reset_plan',
    36 => 'on_action_delay_before_command',
    37 => 'on_action_ascend_at_rate',
    38 => 'on_action_change_mode',
    39 => 'on_action_lotier_max_turns',
    40 => 'on_action_lotier_max_time',
    41 => 'on_action_start_hilsim',
    42 => 'on_action_stop_hilsim'
);

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

        my @last_loads;
        my $index;

        while ($running) {
            my $start_time = time();

            $self->_single_step;

            # Calculate Load
            my $load_avg = 0;
            map { $load_avg += $_ / LOAD_SAMPLES } @last_loads;
            $self->{load} = $load_avg;

            my $total_time = time() - $start_time;
            my $busy_time  = $total_time - $self->{idle_time};

            $last_loads[$index++] = $busy_time / $total_time;
            $index = 0 if ( $index > LOAD_SAMPLES );

        }

        $self->_disconnect;

    };

    if ($@) {
        print STDERR "FATAL: $@\n";
    }

}

sub change_schedule {
    my ( $self, $name, $new_interval ) = @_;
    if ( exists $self->{scheduled_tasks}->{$name} ) {
        $self->{scheduled_tasks}->{$name}->{interval} = $new_interval;
    }
}

sub delete_schedule {
    my ( $self, $name ) = @_;
    delete $self->{scheduled_tasks}->{$name};
}

sub schedule {
    my ( $self, $name, $interval, $code_ref ) = @_;

    unless ( $name and $interval and ref $code_ref eq 'CODE' ) {
        warn 'Can\'t schedule an invalid task';
    }

    $self->{scheduled_tasks}->{$name} = {
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
        $self->schedule( 'heartbeat', DEFAULT_INTERVAL,
            sub { $self->_send_heartbeat } );
    }
}

sub _call_on_start_handler {
    my $self = shift;
    if ( $self->_call_handler('on_start') ) {
        $self->{general_status} = MAV_STATE_STANDBY;
    }
}

sub _dispatch_action_handler {
    my ( $self, $action ) = @_;

    my $handler_name = $action_handler_for{$action};

    $self->_send_action_ack(
        $action,
        (
            exists $self->{handler_for}->{$handler_name}
              and $self->_call_handler($handler_name)
        )
    );
}

sub _process_data_stream_request {
    my ( $self, $id, $rate, $is_required ) = @_;

    my @messages;

    if ( $id == MAV_DATA_STREAM_ALL ) {
        @messages = ( 'send_status', 'send_heartbeat' );
    }

    elsif ( $id == MAV_DATA_STREAM_EXTENDED_STATUS ) {
        @messages = ('send_status');
    }

    foreach (@messages) {
        if ( $is_required and exists $self->{scheduled_tasks}->{$_} ) {
            $self->{scheduled_tasks}->{$_}->{interval} = 1 /$rate;
        }
        elsif ($is_required) {
            my $method = "_$_";
            $self->schedule( $_, 1 / $rate, sub { $self->$method } );
        }
        elsif ( not $is_required and exists $self->{scheduled_tasks}->{$_} ) {
            $self->delete_schedule($_);
        }
    }

}

sub _process_events {
    my $self = shift;

    $self->{socket}->recv( my $buffer, BUFFER_SIZE );
    my $packet = Mavlink2::Input->from($buffer);

    if ($packet) {
        if ( $packet->isa('Mavlink2::HeartBeat')
            and not $self->{is_connected} )
        {
            $self->{is_connected} = 1;
            $self->_call_on_connect_handler;
        }

        elsif ( $packet->isa('Mavlink2::Action')
            and $packet->is_for( $self->{system_id}, $self->{component_id} ) )
        {
            $self->_dispatch_action_handler( $packet->action );
        }

        elsif ( $packet->isa('Mavlink2::RequestDataStream')
            and $packet->is_for( $self->{system_id}, $self->{component_id} ) )
        {
            $self->_process_data_stream_request( $packet->stream_id,
                $packet->stream_rate, $packet->is_required );
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

sub _send_action_ack {
    my ( $self, $action, $result ) = @_;

    $self->{socket}->send(
        Mavlink2::ActionAcknowledge->new( $self->{system_id},
            $self->{component_id}, $action, $result )->serialize
    );

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
            load            => int( $self->{load} * 1000 ),
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
