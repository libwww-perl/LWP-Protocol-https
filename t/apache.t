#!perl -w

use strict;
use Test::More tests => 2;

use LWP::UserAgent;

my $ua = LWP::UserAgent->new();
my $res = $ua->simple_request(HTTP::Request->new(GET => "https://www.apache.org"));

ok($res->is_success);
like($res->content, qr/Apache Software Foundation/);

$res->dump(prefix => "# ");
