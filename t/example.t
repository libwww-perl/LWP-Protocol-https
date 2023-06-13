#!perl -w

use strict;
use Test::More;
use Test::RequiresInternet 'www.example.com' => 443;

use LWP::UserAgent ();

my $ua = LWP::UserAgent->new( ssl_opts => { verify_hostname => 0 } );

plan tests => 2;

my $url = 'https://www.example.com';

subtest "Request GET $url" => sub {
    plan tests => 6;

    my $res = $ua->simple_request(HTTP::Request->new(GET => $url));
    ok($res->is_success, "success status");

    my $h;

    $h = 'X-Died';
    my $x_died = $res->header($h);
    is($x_died, undef, "no $h header");

    $h = 'Client-SSL-Socket-Class';
    my $socket_class = $res->header($h) || '';
    ok($socket_class =~ /\S/, "have header $h");

    SKIP: {
        $h = 'Client-SSL-Version';
        my $ssl_version = $res->header($h) || '';
        my $h_test = $ssl_version =~ /^(SSL|TLS)v\d/i;
        my $want_class = 'IO::Socket::SSL';
        $h_test
            or $socket_class eq $want_class
            or skip "header $h only guaranteed when using $want_class", 1;
        ok($h_test, "have header $h");
    }

    $h = 'Client-SSL-Cipher';
    my $ssl_cipher = $res->header($h) || '';
    ok($ssl_cipher =~ /\S/, "have header $h");

    like($res->content, qr/Example Domain/, "found expected document content");
};

subtest "Check for warnings from GET $url (RT #81948)" => sub {
    plan tests => 2;
    my $warn = '';
    $SIG{__WARN__} = sub { $warn = shift };
    my $res = $ua->simple_request(HTTP::Request->new(GET => $url));
    ok($res->is_success, "success status");
    is($warn, '', "no warning seen");
    $res->dump(prefix => "# ");
};
