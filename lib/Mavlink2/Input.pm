package Mavlink2::Input;

use strict;
use warnings;
use Mavlink2::Constants;
use base qw(Mavlink2::Common);

my $buffer = '';
my $packet_drop_count = 0;

sub from {
    my ( $class, $data ) = @_;
    $buffer .= $data;
    $class->_process_buffer;
}

sub packet_drop_count {
    print "$packet_drop_count\n";
    $packet_drop_count;
}

sub _discard_buffer {
    my $class = shift;
    my $found;
    for my $index ( 0..length($buffer)) {
        my $value = ord(substr($buffer,$index,1));
        if ( $value == SIGNATURE ) {
            $buffer = substr($index,$index);
            $found = 1;
            last;
        }
    }

    $class->_process_buffer if($found);
}

sub _process_buffer {
    my $class = shift;

    my ( $signature, $length ) = unpack( 'CC', $buffer );

    unless ( $signature and $signature == SIGNATURE ) {
        $class->_discard_buffer;
        return;
    }

    if ( $length + 8 >= length($buffer) ) {
        my $packet = substr( $buffer, 1, $length + 5 );
        my $packet_checksum = unpack( 'v', substr( $buffer, $length + 6, 2 ) );
        my $computed_checksum = $class->_compute_checksum($packet);

        unless ( $packet_checksum == $computed_checksum ) {
            $packet_drop_count++;
            $class->_discard_buffer;
            return;
        }
        $buffer = substr( $buffer, $length + 8 );
        return $class->_parse_packet( $packet );
    }
}


sub _parse_packet {
    my ( $class, $packet ) = @_;
    my ( undef, $id ) = unpack('LC',$packet);
    my $pkt_class = $class->class_from_id($id);

    $pkt_class->deserialize($packet) if( $pkt_class);
}

1;
