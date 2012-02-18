#!perl -w

use strict;
use Test::More;

use LWP::UserAgent;

my $ua = LWP::UserAgent->new();
plan skip_all => "Not online" unless $ua->is_online;

plan tests => 2;
my $res = $ua->simple_request(HTTP::Request->new(GET => "https://www.apache.org"));

ok($res->is_success);
like($res->content, qr/Apache Software Foundation/);

$res->dump(prefix => "# ");
