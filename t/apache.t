#!perl -w

use strict;
use Test::More;
use Test::RequiresInternet 'www.apache.org' => 443;

use LWP::UserAgent;

my $ua = LWP::UserAgent->new( ssl_opts => {verify_hostname => 0} );

plan tests => 5;

my $res = $ua->simple_request(HTTP::Request->new(GET => "https://www.apache.org"));

ok($res->is_success);
my $h = $res->header( 'X-Died' );
is($h, undef, "no X-Died header");
like($res->content, qr/Apache Software Foundation/);

# test for RT #81948
my $warn = '';
$SIG{__WARN__} = sub { $warn = shift };
$res = $ua->simple_request(HTTP::Request->new(GET => "https://www.apache.org"));
ok($res->is_success);
is($warn, '', "no warning seen");

$res->dump(prefix => "# ");
