#!/usr/bin/perl

use strict;
use warnings;
use lib './blib/lib';
use Mavlink2;

my $uav = Mavlink2->new(
    system_id    => 4,
    component_id => 200,
    type         => MAV_QUADROTOR,
    autopilot    => MAV_AUTOPILOT_GENERIC
);

$uav->connect('udp://127.0.0.1:14550');

