package dashboard::mydan;
use Dancer ':syntax';
set show_errors => 1;
our $VERSION = '0.1';

get '/mydan/antden.pub' => sub {
    return `cat /opt/mydan/etc/agent/auth/antden.pub`;
};

any '/mydan/install.sh' => sub {
     my $host = request->{host};
    return <<"END";
#!/bin/bash
curl -L http://installbj.mydan.org | MYDanInstallLatestVersion=1 bash
wget 'http://$host/mydan/antden.pub' -O /opt/mydan/etc/agent/auth/antden.pub
END
};

true;
