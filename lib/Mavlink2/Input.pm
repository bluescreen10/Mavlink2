package Mavlink2::Input;

use strict;
use warnings;
use Mavlink2::Constants;
use base qw(Mavlink2::Common);

my $buffer            = '';
my $packet_drop_count = 0;

sub from {
    my ( $class, $data ) = @_;
    $buffer .= $data;

    my $index = index( $buffer, chr(SIGNATURE) );

    if ( $index > -1 ) {
        $buffer = substr( $buffer, $index );
        $class->_process_buffer if ( length($buffer) > 2 );
    } 


    else {
        $buffer = '';
    }

}

sub packet_drop_count {
    $packet_drop_count;
}

sub _process_buffer {
    my $class = shift;

    my ( $signature, $length ) = unpack( 'CC', $buffer );

    if ( $length + 8 >= length($buffer) ) {
        my $packet = substr( $buffer, 1, $length + 5 );
        my $packet_checksum = unpack( 'v', substr( $buffer, $length + 6, 2 ) );
        my $computed_checksum = $class->_compute_checksum($packet);

        unless ( $packet_checksum == $computed_checksum ) {
            $packet_drop_count++;
            $buffer = substr( $buffer, 1 );
            return;
        }

        $buffer = substr( $buffer, $length + 8 );
        return $class->_parse_packet($packet);
    }
}

sub _parse_packet {
    my ( $class, $packet ) = @_;
    my ( $head, $id ) = unpack( 'LC', $packet );

    if ( my $pkt_class = $class->class_from_id( $id ) ) {
         return $pkt_class->deserialize( $packet );
    }
    else {
       print unpack( 'H*', $packet ) . "\n";
       warn "Packet not implemented($id)\n";
    }

    return undef;
}

1;
