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
    eval {
        diag(
            sprintf 'Net::SSLeay::OPENSSL_VERSION_NUMBER() 0x%08x',
            Net::SSLeay::OPENSSL_VERSION_NUMBER()
        );
        1;
    } or diag("Net::SSLeay::OPENSSL_VERSION_NUMBER() unavailable: $@");
    eval {
        diag(
            sprintf 'Net::SSLeay::LIBRESSL_VERSION_NUMBER() 0x%08x',
            Net::SSLeay::LIBRESSL_VERSION_NUMBER()
        );
        1;
    } or diag("Net::SSLeay::LIBRESSL_VERSION_NUMBER() unavailable: $@");
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
