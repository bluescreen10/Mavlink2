#!/usr/bin/perl

use strict;
use warnings;
use lib './blib/lib';
use Mavlink2;
use Mavlink2::Constants;

my $uav = Mavlink2->new(
    system_id    => 4,
    component_id => 200,
    type         => MAV_QUADROTOR,
    autopilot    => MAV_AUTOPILOT_GENERIC
);

$uav->add_handler( 'on_action_set_manual',
    sub { print "hello\n"; $uav->system_mode(MAV_MODE_MANUAL) } );

$uav->connect('udp://127.0.0.1:14550');

