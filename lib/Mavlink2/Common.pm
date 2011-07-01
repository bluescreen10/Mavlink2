package Mavlink2::Common;

use strict;
use warnings;

my $sequence = 0;

my %messages = (
    'Mavlink2::HeartBeat'    => 0,
    'Mavlink2::Boot'         => 1,
    'Mavlink2::SystemTime'   => 2,
    'Mavlink2::SystemStatus' => 34,
);

use constant {
    SIGNATURE        => pack( 'C', 0x55 ),
    INITIAL_CHECKSUM => 0xffff
};

sub class_from_id {
    my ( $class, $id ) = @_;
    while ( my ( $message_class, $message_id ) = each(%messages) ) {
        return $message_class if ( $id == $message_id );
    }
}

sub id_for_class {
    return $messages{ $_[1] };
}

sub _build_packet {
    my ( $class, $system_id, $component_id, $message_id, $payload ) = @_;

    my $packet = pack( 'C*',
        length($payload), $sequence++, $system_id,
        $component_id,    $message_id );

    $sequence = 0 if ( $sequence > 255 );

    $packet .= $payload;

    my $checksum = $class->_compute_checksum($packet);

    return "${\SIGNATURE}$packet" . pack( "v", $checksum );
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
