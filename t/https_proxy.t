#!/usr/bin/perl

# to run test with Net::SSL as backend set environment
# PERL_NET_HTTPS_SSL_SOCKET_CLASS=Net::SSL

use strict;
use warnings;
use Test::More;
use File::Temp 'tempfile';
use IO::Socket::INET;
use IO::Select;
use Socket 'MSG_PEEK';
use LWP::UserAgent;
use LWP::Protocol::https;

plan skip_all => "fork not implemented on this platform" if
    grep { $^O =~m{$_} } qw( MacOS VOS vmesa riscos amigaos );

eval { require IO::Socket::SSL }
    and $IO::Socket::SSL::VERSION >= 1.953
    and eval { require IO::Socket::SSL::Utils }
    or plan skip_all => "no recent version of IO::Socket::SSL::Utils";
IO::Socket::SSL::Utils->import;

# create CA -------------------------------------------------------------
my ($cacert,$cakey) = CERT_create( CA => 1 );
my $cafile = do {
    my ($fh,$fname) = tempfile( CLEANUP => 1 );
    print $fh PEM_cert2string($cacert);
    $fname
};

# create two web servers ------------------------------------------------
my (@server,@saddr);
for my $i (0,1) {
    my $server = IO::Socket::INET->new(
	LocalAddr => '127.0.0.1',
	LocalPort => 0, # let system pick port
	Listen => 10
    ) or die "failed to create INET listener";
    my $saddr = $server->sockhost.':'.$server->sockport;
    $server[$i] = $server;
    $saddr[$i]  = $saddr;
}

my @childs;
END { kill 9,@childs if @childs };
defined( my $pid = fork()) or die "fork failed: $!";

# child process runs _server and exits
if ( ! $pid ) {
    @childs = ();
    exit( _server());
}

# parent continues with closed server sockets
push @childs,$pid;
@server = ();

# check which SSL implementation Net::HTTPS uses
# Net::SSL behaves different than the default IO::Socket::SSL
my $netssl = $Net::HTTPS::SSL_SOCKET_CLASS eq 'Net::SSL';

# do some tests ----------------------------------------------------------
my %ua;
$ua{noproxy} = LWP::UserAgent->new(
    keep_alive => 10, # size of connection cache
    # server does not know the expected name and returns generic certificate
    ssl_opts => { verify_hostname => 0 }
);

$ua{proxy} = LWP::UserAgent->new(
    keep_alive => 10, # size of connection cache
    ssl_opts => {
	# Net::SSL cannot verify hostnames :(
	verify_hostname => $netssl ? 0: 1,
	SSL_ca_file => $cafile
    }
);
$ua{proxy_nokeepalive} = LWP::UserAgent->new(
    keep_alive => 0,
    ssl_opts => {
	# Net::SSL cannot verify hostnames :(
	verify_hostname => $netssl ? 0: 1,
	SSL_ca_file => $cafile
    }
);
$ENV{http_proxy} = $ENV{https_proxy} = "http://foo:bar\@$saddr[0]";
$ua{proxy}->env_proxy;
$ua{proxy_nokeepalive}->env_proxy;
if ($netssl) {
    # Net::SSL cannot get user/pass from proxy url
    $ENV{HTTPS_PROXY_USERNAME} = 'foo';
    $ENV{HTTPS_PROXY_PASSWORD} = 'bar';
}

my @tests = (
    # the expected ids are connid.reqid[tunnel_auth][req_auth]@sslhost
    # because we run different sets of test depending on the SSL class
    # used by Net::HTTPS we replace connid with a letter and later
    # match it to a number

    # keep-alive for non-proxy http
    # requests to same target use same connection, even if intermixed
    [ 'noproxy', "http://$saddr[0]/foo",'A.1@nossl' ],
    [ 'noproxy', "http://$saddr[0]/bar",'A.2@nossl' ], # reuse conn#1
    [ 'noproxy', "http://$saddr[1]/foo",'B.1@nossl' ],
    [ 'noproxy', "http://$saddr[1]/bar",'B.2@nossl' ], # reuse conn#2
    [ 'noproxy', "http://$saddr[0]/tor",'A.3@nossl' ], # reuse conn#1 again
    [ 'noproxy', "http://$saddr[1]/tor",'B.3@nossl' ], # reuse conn#2 again
    # keep-alive for proxy http
    # use the same proxy connection for all even if the target host differs
    [ 'proxy', "http://foo/foo",'C.1.auth@nossl' ],
    [ 'proxy', "http://foo/bar",'C.2.auth@nossl' ],
    [ 'proxy', "http://bar/foo",'C.3.auth@nossl' ],
    [ 'proxy', "http://bar/bar",'C.4.auth@nossl' ],
    [ 'proxy', "http://foo/tor",'C.5.auth@nossl' ],
    [ 'proxy', "http://bar/tor",'C.6.auth@nossl' ],
    # keep-alive for non-proxy https
    # requests to same target use same connection, even if intermixed
    [ 'noproxy', "https://$saddr[0]/foo",'D.1@direct.ssl.access' ],
    [ 'noproxy', "https://$saddr[0]/bar",'D.2@direct.ssl.access' ],
    [ 'noproxy', "https://$saddr[1]/foo",'E.1@direct.ssl.access' ],
    [ 'noproxy', "https://$saddr[1]/bar",'E.2@direct.ssl.access' ],
    [ 'noproxy', "https://$saddr[0]/tor",'D.3@direct.ssl.access' ],
    [ 'noproxy', "https://$saddr[1]/tor",'E.3@direct.ssl.access' ],
    # keep-alive for proxy https
    ! $netssl ? (
	# note that we reuse proxy conn#C in first request. Although the last id
	# from this conn was C.6 the new one is C.8, because request C.7 was the
	# socket upgrade via CONNECT request
	[ 'proxy', "https://foo/foo",'C.8.Tauth@foo' ],
	[ 'proxy', "https://foo/bar",'C.9.Tauth@foo' ],
	# if the target of the tunnel is different we need another connection
	# note that it starts with F.2, because F.1 is the CONNECT request which
	# established the tunnel
	[ 'proxy', "https://bar/foo",'F.2.Tauth@bar' ],
	[ 'proxy', "https://bar/bar",'F.3.Tauth@bar' ],
	[ 'proxy', "https://foo/tor",'C.10.Tauth@foo' ],
	[ 'proxy', "https://bar/tor",'F.4.Tauth@bar' ],
    ):(
	# Net::SSL will cannot reuse socket for CONNECT, but once inside tunnel
	# keep-alive is possible
	[ 'proxy', "https://foo/foo",'G.2.Tauth@foo' ],
	[ 'proxy', "https://foo/bar",'G.3.Tauth@foo' ],
	[ 'proxy', "https://bar/foo",'F.2.Tauth@bar' ],
	[ 'proxy', "https://bar/bar",'F.3.Tauth@bar' ],
	[ 'proxy', "https://foo/tor",'G.4.Tauth@foo' ],
	[ 'proxy', "https://bar/tor",'F.4.Tauth@bar' ],
    ),
    # non-keep alive for proxy https
    [ 'proxy_nokeepalive', "https://foo/foo",'H.2.Tauth@foo' ],
    [ 'proxy_nokeepalive', "https://foo/bar",'I.2.Tauth@foo' ],
    [ 'proxy_nokeepalive', "https://bar/foo",'J.2.Tauth@bar' ],
    [ 'proxy_nokeepalive', "https://bar/bar",'K.2.Tauth@bar' ],
);
plan tests => 2*@tests;

my (%conn2id,%id2conn);
for my $test (@tests) {
    my ($uatype,$url,$expect_id) = @$test;
    my $ua = $ua{$uatype} or die "no such ua: $uatype";

    # Net::SSL uses only the environment to decide about proxy, so we need the
    # proxy/non-proxy environment for each request
    if ( $netssl && $url =~m{^https://} ) {
	$ENV{https_proxy} = $uatype =~m{^proxy} ? "http://$saddr[0]":""
    }

    my $response = $ua->get($url) or die "no response";
    if ( $response->is_success
	and ( my $body = $response->content()) =~m{^ID: *(\d+)\.(\S+)}m ) {
	my $id = [ $1,$2 ];
	my $xid = [ $expect_id =~m{(\w+)\.(\S+)} ];
	if ( my $x = $id2conn{$id->[0]} ) {
	    $id->[0] = $x;
	} elsif ( ! $conn2id{$xid->[0]} ) {
	    $conn2id{ $xid->[0] } = $id->[0];
	    $id2conn{ $id->[0] } = $xid->[0];
	    $id->[0] = $xid->[0];
	}
	is("$id->[0].$id->[1]",$expect_id,"$uatype $url -> $expect_id")
	    or diag($response->as_string);
	# inside proxy tunnel and for non-proxy there should be only absolute
	# URI in request w/o scheme
	my $expect_rqurl = $url;
	$expect_rqurl =~s{^\w+://[^/]+}{}
	    if $uatype eq 'noproxy' or $url =~m{^https://};
	my ($rqurl) = $body =~m{^GET (\S+) HTTP/}m;
	is($rqurl,$expect_rqurl,"URL in request -> $expect_rqurl");
    } else {
	die "unexpected response: ".$response->as_string
    }
}

# ------------------------------------------------------------------------
# simple web server with keep alive and SSL, which can also simulate proxy
# ------------------------------------------------------------------------
sub _server {
    my $connid = 0;
    my %certs; # generated certificates

    ACCEPT:
    my ($server) = IO::Select->new(@server)->can_read();
    my $cl = $server->accept or goto ACCEPT;

    # peek into socket to determine if this is direct SSL or not
    # minimal request is "GET / HTTP/1.1\n\n"
    my $buf = '';
    while (length($buf)<15) {
	my $lbuf;
	if ( ! IO::Select->new($cl)->can_read(30)
	    or ! defined recv($cl,$lbuf,20,MSG_PEEK)) {
	    warn "not enough data for request ($buf): $!";
	    goto ACCEPT;
	}
	$buf .= $lbuf;
    }
    my $ssl_host = '';
    if ( $buf !~m{\A[A-Z]{3,} } ) {
	# does not look like HTTP, assume direct SSL
	$ssl_host = "direct.ssl.access";
    }

    $connid++;

    defined( my $pid = fork()) or die "failed to fork: $!";
    if ( $pid ) {
	push @childs,$pid;
	goto ACCEPT; # wait for next connection
    }

    # child handles requests
    @server = ();
    my $reqid = 0;
    my $tunnel_auth = '';

    SSL_UPGRADE:
    if ( $ssl_host ) {
	my ($cert,$key) = @{
	    $certs{$ssl_host} ||= do {
		diag("creating cert for $ssl_host");
		my ($c,$k) = CERT_create(
		    subject => { commonName => $ssl_host },
		    issuer_cert => $cacert,
		    issuer_key => $cakey,
		    # just reuse cakey as key for certificate
		    key => $cakey,
		);
		[ $c,$k ];
	    };
	};

	IO::Socket::SSL->start_SSL( $cl,
	    SSL_server => 1,
	    SSL_cert => $cert,
	    SSL_key  => $key,
	) or do {
	    diag("SSL handshake failed: ".IO::Socket::SSL->errstr);
	    exit(1);
	};
    }

    REQUEST:
    # read header
    my $req = '';
    while (<$cl>) {
	$_ eq "\r\n" and last;
	$req .= $_;
    }
    $reqid++;
    my $req_auth = $req =~m{^Proxy-Authorization:}mi ? '.auth':'';

    if ( $req =~m{\ACONNECT ([^\s:]+)} ) {
	if ( $ssl_host ) {
	    diag("CONNECT inside SSL tunnel");
	    exit(1);
	}
	$ssl_host = $1;
	$tunnel_auth = $req_auth ? '.Tauth':'';
	#diag($req);

	# simulate proxy and establish SSL tunnel
	print $cl "HTTP/1.0 200 ok\r\n\r\n";
	goto SSL_UPGRADE;
    }

    if ( $req =~m{^Content-length: *(\d+)}mi ) {
	read($cl,my $buf,$1) or die "eof while reading request body";
    }
    my $keep_alive =
	$req =~m{^(?:Proxy-)?Connection: *(?:(keep-alive)|close)}mi ? $1 :
	$req =~m{\A.*HTTP/1\.1} ? 1 :
	0;

    # just echo request back, including connid and reqid
    my $body = "ID: $connid.$reqid$tunnel_auth$req_auth\@"
	. ( $ssl_host || 'nossl' )."\n"
	. "---------\n$req";
    print $cl "HTTP/1.1 200 ok\r\nContent-type: text/plain\r\n"
	. "Connection: ".( $keep_alive ? 'keep-alive':'close' )."\r\n"
	. "Content-length: ".length($body)."\r\n"
	. "\r\n"
	. $body;

    goto REQUEST if $keep_alive;
    exit(0); # done handling requests
}
