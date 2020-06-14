package dashboard::user;
use Dancer ':syntax';
use JSON;

use Tie::File;
use dashboard;
our $VERSION = '0.1';

our $path; 
BEGIN{ 
    my %antden = MYDan::Util::OptConf->load()->dump( 'antden' );
    $path = $antden{dashboard}{'auth'};
};

any '/user/settings' => sub {
    my $param = params();
    return unless my $username = dashboard::get_username();

    die "tie auth $username fail" unless tie my @token, 'Tie::File', "$path/$username.pub";

    @token = ( $param->{token} ) if $param->{token};

    template 'user/settings', +{ 
        serveraddr => "http://".request->{host},
        username => $username,
        token => join( "\n", @token), 
    };
};

true;
 
