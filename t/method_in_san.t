use warnings;
use strict;
use Test::More;
#--------------------------------------------------------------
# this is just for testing the '_in_san()' method
#--------------------------------------------------------------
use LWP::Protocol::https;
sub class_under_test { return bless {}, 'LWP::Protocol::https'; }
#-----------------------------
test__in_san();
test__cn_match();
test__extra_sock_opts();

#-----------------
sub test__in_san {
    my $class = class_under_test();
    can_ok( $class, '_in_san' );
    {
        no strict qw(refs);          ## no critic (ProhibitNoStrict)
        no warnings qw(redefine);    ## no critic (ProhibitNoWarnings)

        # a bit of a monkey patch to make it simpler to test
        # the various basic cases under test
        
        my $p_cert = bless {}, 'fauxCert';
        my @san_list;
        my $p_peer_certificate = 'fauxCert::peer_certificate';
        local *{$p_peer_certificate}  = sub {
             return @san_list;
        };
        
        #-----------------------------------
        # We need three simple cases, one without SAN
        # one with a pass, one with a fail connection.
        # until we need to deal with more than just the simple dns_match
        # futureNote: what if we use the 'type_id' -- and need to dispatch
        # to other than the '_cn_match()' method -- we may want to extend this 
        # basic list of tests.
        my @tests = (
            {
                'san'   => [],
                'cn'    => '/CN=foo.bar.baz',
                'want'  => undef,
                'label' => 'empty SAN',
            },
            {
                'san'   => [2, '*.bar.baz'],
                'cn'    => '/CN=foo.bar.baz',
                'want'  => 'ok',
                'label' => 'CN matched by wild card SAN',
            },
            {
                'san'   => [2, '*.bar.baz',],
                'cn'    => '/CN=cat.rat.bat',
                'want'  => undef,
                'label' => 'CN not in SAN',
            }
        );
        
        foreach my $test (@tests) {
             my ($san, $cn,$want, $label) =  @{$test}{qw(san cn want label)};
             @san_list = @{$san};
             my $have = $class->_in_san($cn, $p_cert);
             is($have, $want, $label);
        }
    }
    return;
}

sub test__cn_match {
    my $class = class_under_test();
    can_ok( $class, '_cn_match' );

    # [ common_name , san_name, must_match , 'label' ]

    my @fail_cases = (
        ['hostbar.foo' ,'ho*bar.foo'    ,0, 'inline wildcard' ],
        ['host.cat.foo','host.*.foo'    ,0, 'wildcard between levels' ],
        ['host.foo.bar','*foo.bar'      ,0, 'wild card without a dot'],
        ['abcdfoo.com' ,'*.foo.com'     ,0, 'different domain name'],
        ['*.foo.com'   ,'*.foo.com'     ,0, 'wild card query CN must be FQDN'],
        ['baz.foo.bar' ,'*.red.foo.bar' ,0, 'wild card from the section below'],
        ['baz.foo.bar' ,'*.foo.bar.'    ,0, 'extra dot in SAN -- "dns style" dot at the end' ],
    );
    my @ok_cases = (
        ['baz.foo.bar' ,'baz.foo.bar'   ,1, 'matches directly' ],
        ['baz.foo.bar' ,'*.foo.bar'     ,1, 'matches by wild card' ],
    );
    # Include these non-dns-specific-cases, as they could be things that
    # might be passed in the /CN= and be a part of the SAN, but it is 
    # not quite clear which way they should be addressed. Nor is it clear
    # that they should be rejected by the _cn_match()
    my @non_dns_specific_cases = (
        ['127.0.0.1'   , '127.0.0.1'    ,1, 'dotQuad notation' ],
        ['bob@bob.com' , 'bob@bob.com'  ,1, 'email compare' ],
        ['schem://host', 'schem://host' ,1, 'url compare' ],
    );
    my @tests = (@fail_cases, @ok_cases, @non_dns_specific_cases );
    
    # now we can just iterate over the groups
    foreach my $test ( @tests) {
        my ( $cn, $san_dns, $must_match, $label ) = @{$test};
        my $match = $class->_cn_match($cn, $san_dns);
        my $test_label = sprintf("%12s ~ %14s : %s", $cn,$san_dns,$label);
        is($match, $must_match, $test_label);
    }
    
    return;
}

sub test__extra_sock_opts {
    my $class = class_under_test();
    can_ok( $class, '_extra_sock_opts' );

    $class->{ua}{ssl_opts} = { verify_hostname => 0 };
    my %options = $class->_extra_sock_opts();
    is_deeply( \%options, { SSL_verify_mode => 0, }, "No SSL verification done");

    {
        no warnings qw(redefine once);
        $INC{'Mozilla/CA.pm'} = 1;
        local *Mozilla::CA::SSL_ca_file = sub {
            return '/var/tmp/meuk';
        };

        $class->{ua}{ssl_opts} = { verify_hostname => 1 };
        my %options = $class->_extra_sock_opts();
        is_deeply(
            \%options,
            {
                SSL_verifycn_scheme => 'www',
                SSL_verify_mode     => 1,
                SSL_ca_file         => '/var/tmp/meuk'
            },
            "SSL verification done"
        );

        $class->{ua}{ssl_opts} = { };
        %options = $class->_extra_sock_opts();
        is_deeply(
            \%options,
            {
                SSL_verifycn_scheme => 'www',
                SSL_verify_mode     => 1,
                SSL_ca_file         => '/var/tmp/meuk'
            },
            "SSL verification done"
        );
    }
}

done_testing();
# the end
