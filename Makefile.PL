#!perl -w

require 5.008001;
use strict;
use ExtUtils::MakeMaker;

my $developer = -f '.gitignore';
ExtUtils::MakeMaker->VERSION(6.98) if $developer;

my %WriteMakefileArgs = (
    NAME => 'LWP::Protocol::https',
    VERSION_FROM => 'lib/LWP/Protocol/https.pm',
    ABSTRACT_FROM => 'lib/LWP/Protocol/https.pm',
    AUTHOR => 'Gisle Aas <gisle@activestate.com>',
    LICENSE => 'perl_5',

    META_ADD => {
        prereqs => {
            configure => {
                requires => {
                    'ExtUtils::MakeMaker' => '0',
                },
            },
            runtime => {
                requires => {
                    'LWP::UserAgent' => '6.06',
                    'Net::HTTPS' => 6,
                    'IO::Socket::SSL' => "1.54",
                    'Mozilla::CA' => "20110101",
                    'perl' => '5.008001',
                },
            },
            test => {
                requires => {
                    'Test::More' => '0',
                    'Test::RequiresInternet' => 0,
                },
            },
        },
    },

    META_MERGE => {
	resources => {
            repository => 'http://github.com/libwww-perl/lwp-protocol-https',
	    MailingList => 'mailto:libwww@perl.org',
        }
    },
);

my $eumm_version  = eval $ExtUtils::MakeMaker::VERSION;

for (qw(configure build test runtime)) {
    my $key = $_ eq 'runtime' ? 'PREREQ_PM' : uc $_.'_REQUIRES';
    next unless exists $WriteMakefileArgs{META_ADD}{prereqs}{$_}
             or exists $WriteMakefileArgs{$key};
    my $r = $WriteMakefileArgs{$key} = {
        %{$WriteMakefileArgs{META_ADD}{prereqs}{$_}{requires} || {}},
        %{delete $WriteMakefileArgs{$key} || {}},
    };
    defined $r->{$_} or delete $r->{$_} for keys %$r;
}

# dynamic prereqs get added here.

$WriteMakefileArgs{MIN_PERL_VERSION} = delete $WriteMakefileArgs{PREREQ_PM}{perl} || 0;

die 'attention developer: you need to do a sane meta merge here!'
    if keys %{$WriteMakefileArgs{BUILD_REQUIRES}};

$WriteMakefileArgs{BUILD_REQUIRES} = {
    %{$WriteMakefileArgs{BUILD_REQUIRES} || {}},
    %{delete $WriteMakefileArgs{TEST_REQUIRES}}
} if $eumm_version < 6.63_03;

$WriteMakefileArgs{PREREQ_PM} = {
    %{$WriteMakefileArgs{PREREQ_PM}},
    %{delete $WriteMakefileArgs{BUILD_REQUIRES}}
} if $eumm_version < 6.55_01;

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
    if $eumm_version < 6.51_03;

delete $WriteMakefileArgs{MIN_PERL_VERSION}
    if $eumm_version < 6.48;

delete @WriteMakefileArgs{qw(META_ADD META_MERGE)}
    if $eumm_version < 6.46;

delete $WriteMakefileArgs{LICENSE}
    if $eumm_version < 6.31;

WriteMakefile(%WriteMakefileArgs);
