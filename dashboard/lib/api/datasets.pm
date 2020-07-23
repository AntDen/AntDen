package api::datasets;
use Dancer ':syntax';
use POSIX;
use FindBin qw( $RealBin );
use JSON;
use YAML::XS;

set serializer => 'JSON';
set show_errors => 1;

our $VERSION = '0.1';
our %addr;

BEGIN{
    my @addr = `cat $RealBin/../whitelist`;
    chomp @addr;
    %addr = map{ $_ => 1 }@addr;
};

any '/api/datasets/create' => sub {
    my $addr = request->env->{REMOTE_ADDR};
    return( 'Unauthorized:' . $addr ) unless $addr{$addr} || $addr =~ /^172\./;
    my $param = params();

    return +{ stat => JSON::false, info => YAML::XS::Dump $param } unless 5 eq grep{ $param->{$_} }qw( name info type group token );
    $dashboard::schedulerDB->insertDatasets( @$param{qw( name info type group token ) } );

    return +{ stat => JSON::true, data => [] };
};

any '/api/datasets/addauth' => sub {
    my $addr = request->env->{REMOTE_ADDR};
    return( 'Unauthorized:' . $addr ) unless $addr{$addr} || $addr =~ /^172\./;
    my $param = params();

    return +{ stat => JSON::false, info => '' } unless $param->{name} && $param->{group} && $param->{user};
    $dashboard::schedulerDB->insertDatasetsauth( $param->{name}, $param->{group}, $param->{user} );

    return +{ stat => JSON::true, data => [] };
};

true;
