use warnings;
use strict;
use Test::More tests => 7;
#--------------------------------------------------------------
# this is just for testing the '_in_san()' method
#--------------------------------------------------------------

# This is our class_under_test
use LWP::Protocol::https;
sub class_under_test { return 'LWP::Protocol::https'; }
#-----------------------------
test_run();

#-----------------
sub test_run {
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
        # the first case we have nothing in the peer_certificate()
        my $check = '/CN=krypton-oozie.red.funspace.notTLD';
        my $have = $class->_in_san($check, $p_cert);
        ok( !$have, 'not ok -- no san_list');
        @san_list =( 
            2, 'cat.hat.rat.bat', 
            2, '*.funspace.notTLD',
            2, '*.blue.funspace.notTLD',
            2, '*.red.funspace.notTLD'
        );
        # and now we get it as a part of the last on the list
        $have = $class->_in_san($check, $p_cert);
        ok( $have, 'ok for krypton-oozie.red.funspace.notTLD');
        # now the just name
        $check = '/CN=cat.hat.rat.bat';
        $have = $class->_in_san($check, $p_cert);
        ok( $have, 'ok for cat.hat.rat.bat');
        # and the not case of below the dot,
        # the rule is that a dot stops a '*'
        $check = '/CN=cat.black.blue.funspace.notTLD';
        $have = $class->_in_san($check, $p_cert);
        ok( !$have, 'not ok -- cat.black.blue.funspace.notTL');
        #-------------------------------------------------------
        # what if there is a mal formed space?
        # friends made the funny of a self signed cert
        # that ended in a '.' -- so need to test it will fail.
        @san_list =( 
            2, '*.red.funspace.notTLD.'
        );
        $check = '/CN=krypton-oozie.red.funspace.notTLD';
        $have = $class->_in_san($check, $p_cert);
        ok( !$have, 'not ok -- malformed SAN name');
        #-----------------------------------------------
        # need to guard the '.' in any of the sans as reges
         @san_list =( 
            2, '*.red.funspace.notTLD'
        );
        $check = '/CN=krypton-oozieDred.funspace.notTLD';
        $have = $class->_in_san($check, $p_cert);
        ok( !$have, 'not ok -- malformed SAN name');
        
    }
    return;
}

# the end
