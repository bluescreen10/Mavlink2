#!perl

use strict;
use warnings;
use ExtUtils::MakeMaker;

# Write Makefile
WriteMakefile(
    NAME         => 'Mavlink2',
    ABSTRACT     => 'Mavlink2 implementation for Perl',
    AUTHOR       => 'Mariano Wahlmann <dichoso@gmail.com>',
    VERSION_FROM => 'lib/Mavlink2.pm',
    PREREQ_PM    => {
        'Test::More'    => 0,
    },
    test      => { TESTS => 't/*.t' }
);
