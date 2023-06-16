on 'configure' => sub {
    requires "ExtUtils::MakeMaker" => "0";
    requires "perl" => "5.008001";
};

on 'runtime' => sub {
    requires "base" => "0";
    requires "IO::Socket::SSL" => "1.970";
    requires "LWP::Protocol::http" => "0";
    requires "LWP::UserAgent" => "6.06";
    requires "Net::HTTPS" => "6";
    requires "perl" => "5.008001";
    requires "strict" => "0";
};

on 'test' => sub {
    requires "File::Temp" => "0";
    requires "IO::Select" => "0";
    requires "IO::Socket::INET" => "0";
    requires "IO::Socket::SSL" => "1.54";
    requires "IO::Socket::SSL::Utils" => "0";
    requires "LWP::UserAgent" => "6.06";
    requires "perl" => "5.008001";
    requires "Socket" => "0";
    requires "Test::More" => "0.96";
    requires "Test::RequiresInternet" => "0";
    requires "warnings" => "0";
};

on 'develop' => sub {
    requires 'Test::CheckManifest' => '1.29';
    requires 'Test::CleanNamespaces';
    requires "Test::CPAN::Changes" => "0.19";
    requires 'Test::CPAN::Meta';
    requires 'Test::Kwalitee';
    requires 'Test::Kwalitee'      => '1.22';
    requires 'Test::Pod::Spelling::CommonMistakes' => '1.000';
};
