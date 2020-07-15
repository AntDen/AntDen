package dashboard::userinfo;
use Dancer ':syntax';
use JSON;
use Digest::MD5;
use dashboard;
our $VERSION = '0.1';

any '/userinfo/login' => sub {
    my $param = params();
    my ( $user, $pass, $err ) = @$param{qw( user pass )};

    if( defined $user & defined $pass )
    {
        my @info = $dashboard::schedulerDB->selectUserinfoByPass( $user, Digest::MD5->new->add($pass)->hexdigest );

        my @chars = ( "A" .. "Z", "a" .. "z", 0 .. 9 );
        my $keys = join("", @chars[ map { rand @chars } ( 1 .. 64 ) ]);

        if( @info )
        {
            $dashboard::schedulerDB->updateUserinfoExpire( time + 8 * 3600, $keys, $user );
            $dashboard::schedulerDB->commit;
            set_cookie( sid => $keys, http_only => 0, expires => time + 8 * 3600 );
            redirect $param->{callback} || '/';
        }
        else
        {
            $err = 'Incorrect user password!!!';
        }
    }

    template 'userinfo/login', +{ err => $err }, { layout => 0 };
};

any '/userinfo/logout' => sub {
    my $sid = cookie( "sid" );
    $dashboard::schedulerDB->updateUserinfoSid( $sid )
        if $sid && $sid =~ /^[a-zA-Z0-9]{64}$/;
    redirect "/";
};

any '/userinfo/info' => sub {
    my $sid = cookie( "sid" );
    return +{ stat => JSON::false, info => 'sid format err' }
        unless $sid && $sid =~ /^[a-zA-Z0-9]{64}$/;

    my @u = $dashboard::schedulerDB->selectUserinfoBySid( $sid );
    return +{ stat => JSON::true, data => +{ user => $u[0][0] } } if @u;
    return +{ stat => JSON::false, info => 'Not logged in yet' };
};

get '/userinfo/adduser' => sub {
    my ( $username, $level ) = dashboard::admin::adminInfo();
    return 'Unauthorized:'. $username unless $level;
    my $param = params();

    $dashboard::schedulerDB->insertUserinfo(
        $param->{user}, Digest::MD5->new->add('changeme')->hexdigest
    ) if $param->{user};
    $dashboard::schedulerDB->deleteUserinfoById( $param->{deleteid} ) if $param->{deleteid};

    my @user = $dashboard::schedulerDB->selectUserinfo();
    template 'userinfo/adduser', +{ admin => 1, user => \@user };
};

any '/userinfo/chpasswd' => sub {
    my $param = params();
    my ( $oldpass, $newpass1, $newpass2, $err ) = @$param{qw( oldpass newpass1 newpass2 )};

    return unless my $user = dashboard::get_username();

    if( defined $oldpass & defined $newpass1 & defined $newpass2 )
    {
        return template 'userinfo/chpasswd', +{ err => 'The two new passwords are different!' }
            unless $newpass1 eq $newpass2;

        my @info = $dashboard::schedulerDB->selectUserinfoByPass( $user, Digest::MD5->new->add($oldpass)->hexdigest );
        if( @info )
        {
            $dashboard::schedulerDB->updateUserinfoPass( Digest::MD5->new->add($newpass1)->hexdigest, $user);
            $dashboard::schedulerDB->commit;
        }
        else
        {
            $err = 'Incorrect user password!!!';
        }
    }

    template 'userinfo/chpasswd', +{ err => $err };
};

true;
