# NAME

LWP::Protocol::https - Provide https support for LWP::UserAgent

# SYNOPSIS

    use LWP::UserAgent;

    $ua = LWP::UserAgent->new(ssl_opts => { verify_hostname => 1 });
    $res = $ua->get("https://www.example.com");

    # specify a CA path
    $ua = LWP::UserAgent->new(
        ssl_opts => {
            SSL_ca_path     => '/etc/ssl/certs',
            verify_hostname => 1,
        }
    );

# DESCRIPTION

The LWP::Protocol::https module provides support for using https schemed
URLs with LWP.  This module is a plug-in to the LWP protocol handling, so
you don't use it directly.  Once the module is installed LWP is able
to access sites using HTTP over SSL/TLS.

If hostname verification is requested by LWP::UserAgent's `ssl_opts`, and
neither `SSL_ca_file` nor `SSL_ca_path` is set, then `SSL_ca_file` is
implied to be the one provided by [Mozilla::CA](https://metacpan.org/pod/Mozilla%3A%3ACA).  If the Mozilla::CA module
isn't available SSL requests will fail.  Either install this module, set up an
alternative `SSL_ca_file` or disable hostname verification.

This module used to be bundled with the libwww-perl, but it was unbundled in
v6.02 in order to be able to declare its dependencies properly for the CPAN
tool-chain.  Applications that need https support can just declare their
dependency on LWP::Protocol::https and will no longer need to know what
underlying modules to install.

# SEE ALSO

[IO::Socket::SSL](https://metacpan.org/pod/IO%3A%3ASocket%3A%3ASSL), [Crypt::SSLeay](https://metacpan.org/pod/Crypt%3A%3ASSLeay), [Mozilla::CA](https://metacpan.org/pod/Mozilla%3A%3ACA)

# COPYRIGHT & LICENSE

Copyright (c) 1997-2011 Gisle Aas.

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
