package Mavlink2::Common;

use strict;
use warnings;

our $SEQUENCE = 0;

use constant {
    SIGNATURE        => pack( 'C', 0x55 ),
    INITIAL_CHECKSUM => 0xffff
};

sub _build_packet {
    my ( $class, $system_id, $component_id, $message_id, $payload ) = @_;

    my $packet = pack( 'C*',
        length($payload), $SEQUENCE++, $system_id,
        $component_id,    $message_id );

    $packet .= $payload;

    my $checksum = $class->_compute_checksum($packet);

    return SIGNATURE . $packet . pack( "CC", $checksum & 0xff, $checksum >> 8 );
}

sub _compute_checksum {
    my ( $self, $data ) = @_;

    my $checksum = INITIAL_CHECKSUM;

    # Byte-by-Byte
    foreach ( split( '', $data ) ) {
        $checksum = $self->_accumulate_checksum( ord($_), $checksum );
    }

    return $checksum;
}

sub _accumulate_checksum {
    my ( $self, $value, $checksum ) = @_;

    my $tmp = ( $value ^ ( $checksum & 0xff ) );
    $tmp ^= ( $tmp << 4 ) & 0xff;
    return (
        ( $checksum >> 8 ) ^ ( $tmp << 8 ) ^ ( $tmp << 3 ) ^ ( $tmp >> 4 ) );

}

1;
