#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 1;
use Mavlink2::Constants;
use Mavlink2::Common::HeartBeat;

my $packet =
  Mavlink2::Common::HeartBeat->new( 4, 200, MAV_FIXED_WING,
    MAV_AUTOPILOT_GENERIC )->serialize;

is( unpack( 'H*', $packet ), '55030004c800010002698e', 'Hex dump package' );
