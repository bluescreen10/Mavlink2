#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 5;

use_ok('Mavlink2');
use_ok('Mavlink2::Vehicle');
use_ok('Mavlink2::Common');
use_ok('Mavlink2::Constants');
use_ok('Mavlink2::Common::HeartBeat');
