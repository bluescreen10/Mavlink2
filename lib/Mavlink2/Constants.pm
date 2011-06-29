package Mavlink2::Constants;

use strict;
use warnings;
use base qw(Exporter);

use constant {

    # General
    MAVLINK_VERSION => 2,
    SIGNATURE       => 0x55,

    # MAV Type
    MAV_GENERIC    => 0,
    MAV_FIXED_WING => 1,
    MAV_QUADROTOR  => 2,
    MAV_COAXIAL    => 3,
    MAV_HELICOPTER => 4,
    MAV_GROUND     => 5,
    OCU            => 6,

    # MAV Autopilot Type
    MAV_AUTOPILOT_GENERIC       => 0,
    MAV_AUTOPILOT_PIXHAWK       => 1,
    MAV_AUTOPILOT_SLUGS         => 2,
    MAV_AUTOPILOT_ARDUPILOTMEGA => 3,

};

our @EXPORT = qw(
  MAVLINK_VERSION SIGNATURE

  MAV_GENERIC MAV_FIXED_WING MAV_QUADROTOR
  MAV_COAXIAL MAV_HELICOPTER MAV_GROUND OCU

  MAV_AUTOPILOT_GENERIC MAV_AUTOPILOT_PIXHAWK
  MAV_AUTOPILOT_SLUGS MAV_AUTOPILOT_ARDUPILOTMEGA

);

1;
