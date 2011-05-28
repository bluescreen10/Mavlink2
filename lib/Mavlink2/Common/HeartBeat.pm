package Mavlink2::Common::HeartBeat;

use strict;
use warnings;
use Mavlink2::Constants;
use base qw(Mavlink2::Common);

use constant MESSAGE_ID => 0;

sub new {
    my ( $class, $system_id, $component_id, $type, $autopilot ) = @_;

    my $payload = pack( 'C*', $type, $autopilot, MAVLINK_VERSION );

    return $class->_build_packet($system_id, $component_id, MESSAGE_ID, $payload);
}

1;
