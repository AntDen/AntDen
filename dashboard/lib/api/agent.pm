package api::agent;
use Dancer ':syntax';
use JSON;
use dashboard;
use MYDan::Util::OptConf;
use MYDan::Agent::Query;
use YAML::XS;

our $VERSION = '0.1';

our ( %agent, %antden ); 
BEGIN{ 
    %agent  = MYDan::Util::OptConf->load()->dump( 'agent' );
    %antden = MYDan::Util::OptConf->load()->dump( 'antden' );
};

any '/api/v1/agent/encryption' => sub {
    my ( $raw, $query, $yaml ) = request->body;

    return 'invalid query' unless
        ( $yaml = Compress::Zlib::uncompress( $raw ) )
        && eval { $query = YAML::XS::Load $yaml }
        && ref $query eq 'HASH';

    my $auth = delete $query->{auth};
    return "no auth" unless $auth && %$auth;

    map{ return "no $_" unless $query->{$_} }qw( user peri node code );
    return 'user format error' unless $query->{user} =~ /^[\@a-zA-Z0-9\._-]+$/;

    eval{
        return 'auth fail' unless MYDan::Agent::Auth->new(
            pub => $antden{dashboard}{'auth'}, user => $query->{user}
        )->verify( $auth, YAML::XS::Dump $query );
    };

    return "verify fail:$@" if $@;

    my @peri = split '#', $query->{peri};
    return 'peri fail' unless $peri[0] < time && time < $peri[1];

    my ( $user, $sudo, $node, $code ) = @$query{qw( user sudo node code )};

    if( $code eq 'antdencli' )
    {
        delete $query->{node};
    }
    else
    {
        my @x = $dashboard::schedulerDB->selectIsAdmin( $user );
        my $level = 0; map{ $level = $_->[2] if $level < $_->[2] }@x;
        if( $level )
        {
            delete $query->{node};
        }
        else
        {
            my @ip = $dashboard::schedulerDB->selectMachineInfoByUser( $user );
            my %ip = map{ $_->[0] => 1 }@ip;
            $query->{node} = +{ map{ $_ => 1 }grep{ $ip{$_} }@$node };
        }
    }

    $query->{sudo} = $query->{user} unless $sudo;
    $query->{auth} = eval{ 
        MYDan::Agent::Auth->new( key => $agent{'auth'} )
            ->sign( YAML::XS::Dump $query );
    };
    return  "sign error: $@" if $@;
    my $r =  Compress::Zlib::compress( YAML::XS::Dump $query );
    send_file( \$r, content_type => 'image/png' );
};

true;
