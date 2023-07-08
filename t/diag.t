#!perl

use strict;
use warnings;

use IO::Select             ();
use IO::Socket::INET       ();
use IO::Socket::SSL        ();
use IO::Socket::SSL::Utils ();
use Socket                 ();
use Test::More import => [qw( diag done_testing pass subtest )];
use Test::Needs;
use Try::Tiny qw( try );

subtest 'openssl' => sub {
    test_needs 'Capture::Tiny';
    test_needs 'File::Which';
    my $openssl = File::Which::which('openssl');
    diag "path to openssl: $openssl";
    ## no critic (InputOutput::RequireCheckedSyscalls)
    my ( $stdout, $stderr )
        = Capture::Tiny::capture( sub { system( $openssl, 'version' ) } );

    diag "stdout: $stdout" if $stdout;
    diag "stderr: $stderr" if $stderr;
    pass('openssl version');
};

subtest 'net_ssleay' => sub {
    test_needs 'Net::SSLeay';
    try {
        diag(
            sprintf 'Net::SSLeay::OPENSSL_VERSION_NUMBER() 0x%08x',
            Net::SSLeay::OPENSSL_VERSION_NUMBER()
        );
    };
    try {
        diag(
            sprintf 'Net::SSLeay::LIBRESSL_VERSION_NUMBER() 0x%08x',
            Net::SSLeay::LIBRESSL_VERSION_NUMBER()
        );
    };
    pass('Net::SSLeay');
};

subtest 'modules' => sub {
    diag "IO::Select $IO::Select::VERSION";
    diag "IO::Socket::INET $IO::Socket::INET::VERSION";
    diag "IO::Socket::SSL $IO::Socket::SSL::VERSION";
    diag "IO::Socket::SSL::Utils $IO::Socket::SSL::Utils::VERSION";
    diag "Socket $Socket::VERSION";
    pass('modules');
};

done_testing();
