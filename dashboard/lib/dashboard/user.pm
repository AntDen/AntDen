package dashboard::user;
use Dancer ':syntax';
use JSON;

use Digest::MD5;
use Tie::File;
use dashboard;
our $VERSION = '0.1';

our $path; 
BEGIN{ 
    my %antden = MYDan::Util::OptConf->load()->dump( 'antden' );
    $path = $antden{dashboard}{'auth'};
};

any '/user/settings/machine' => sub {
    my $param = params();
    return unless my $username = dashboard::get_username();

    die "tie auth $username fail" unless tie my @token, 'Tie::File', "$path/$username.pub";

    @token = ( $param->{token} ) if $param->{token};

    template 'user/settings/machine', +{ 
        serveraddr => "http://".request->{host},
        username => $username,
        token => join( "\n", @token), 
    };
};

any '/user/settings/docker' => sub {
    my ( $param, $err ) = params();
    return unless my $username = dashboard::get_username();

    if( request->method eq 'POST' )
    {
        unlink "$path/$username.pub", "$path/$username";
        $err = "ssh-keygen fail: $!" if system "ssh-keygen -t rsa -f $path/$username -P \"\" >/dev/null 2>&1";
    }

    my $cont = `cat '$path/$username'`;
    my $md5 = Digest::MD5->new->add( $cont )->hexdigest;
    template 'user/settings/docker', +{ 
        serveraddr => "http://".request->{host},
        username => $username,
        md5 => $md5,
        err => $err,
    };
};

any '/user/settings/antdencli' => sub {
    my $param = params();
    my ( $user, $md5 ) = @$param{qw( user md5 )};

    return "user is undefined or malformed" unless $user && $user =~ /^[\.:a-zA-Z0-9_\@\-]+$/;
    return "md5 is undefined or malformed" unless $md5 && $md5 =~ /^[a-zA-Z0-9]+$/;

    my $cont = `cat $path/../scripts/antdencli.scripts`;
    my $host = request->{host};
    $cont =~ s/XXX_MYDan_api_XXX/$host/;
    $cont =~ s/XXX_MYDan_username_XXX/$user/;
    $cont =~ s/XXX_MYDan_keymd5_XXX/$md5/;
    return $cont;
};

any '/user/settings/key' => sub {
    my $param = params();
    my ( $user, $md5 ) = @$param{qw( user md5 )};
    return "user is undefined or malformed" unless $user && $user =~ /^[\.:a-zA-Z0-9_\@\-]+$/;
    return "md5 is undefined or malformed" unless $md5 && $md5 =~ /^[a-zA-Z0-9]+$/;
    my $cont = `cat '$path/$user'`;
    return "md5 no" if $md5 ne Digest::MD5->new->add( $cont )->hexdigest;
    return $cont;
};

true;
