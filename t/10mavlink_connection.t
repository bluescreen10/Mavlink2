#!/usr/bin/perl

use strict;
use warnings;
use Mavlink2;
use Mavlink2::Vehicle;
use Mavlink2::Constants;
use IO::Socket::INET;
use Time::HiRes qw(time);
use Test::More;
use constant {
    INTERVAL    => 3,
    COUNT       => 5,
    BUFFER_SIZE => 2048,
};

$| = 1;    #autoflush

plan tests => COUNT + 1;

# Start server;
my $server = IO::Socket->new(
    Domain    => AF_INET,
    Proto     => 'udp',
    LocalAddr => '127.0.0.1'
);

my $port = $server->sockport;

# Server
if ( my $pid = fork() ) {

    $SIG{ALRM} = sub {
        kill( 'TERM', $pid );
        die 'Server Timeout';
    };

    alarm( INTERVAL * COUNT + 1 );

    my $count    = 0;
    my $ts       = time();
    my $acc_time = 0;

    while ( $count++ < COUNT ) {
        $server->recv( my $buffer, BUFFER_SIZE );

        # Discard first package
        $acc_time += time() - $ts if ( $count > 1 );
        $ts = time();

        # Echo back
        $server->send($buffer);

        like( $buffer, qr/^U/, "HeartBeat $count" );
    }

    alarm 0;

    $count -= 2;
    cmp_ok( abs( $acc_time / $count - INTERVAL ), '<=', 0.5, 'Avg. Interval' );
    kill( 'INT', $pid );
    $server->close;
}

# Client
else {
    my $link = Mavlink2->new(
        server             => "udp://127.0.0.1:$port",
        heartbeat_interval => INTERVAL
    );

    my $mav = Mavlink2::Vehicle->new(
        system_id    => 4,
        component_id => 200,
        type         => MAV_FIXED_WING,
        autopilot    => MAV_AUTOPILOT_GENERIC
    );

    $link->register($mav);
    $link->run;
    exit;
}

