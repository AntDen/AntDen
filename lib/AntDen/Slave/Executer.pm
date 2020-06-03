package AntDen::Slave::Executer;
use strict;
use warnings;

use Carp;
use YAML::XS;

use AntDen::Slave::Executer::Code;

sub new
{
    my ( $class, %this ) = @_;

    map{ die "$_ undef" unless $this{$_} && -d $this{$_}; }qw( code conf );
    $this{ec} = AntDen::Slave::Executer::Code->new( path => $this{code} );

    bless \%this, ref $class || $class;
}

sub _config
{
    my ( $this, $taskid ) = @_;
    my $conf = eval{ YAML::XS::LoadFile "$this->{conf}/$taskid" };
    die "load config fail: $@" if $@;

    die "nofind executer on config"
        unless $conf->{executer} &&
            ref $conf->{executer} eq 'HASH' &&
            $conf->{executer}{name};

    return $conf;
}

sub start
{
    my ( $this, $taskid ) = @_;
    my $conf = $this->_config( $taskid );

    my $executeid = eval{ 
        $this->{ec}->do( 
            $conf->{executer}{name},
            'start',
            +{
                resources => $conf->{resources}, 
                param => $conf->{executer}{param},
                taskid => $taskid
            } 
        )
    };
    die "run code $conf->{executer}{name}/start fail: $@" if $@;
    die "start task code return error" unless defined $executeid;
    return $executeid;
}

sub stop
{
    my ( $this, $taskid, $executeid, $stopcount ) = @_;

    my $conf = $this->_config( $taskid );

    eval{ $this->{ec}->do( $conf->{executer}{name}, 'stop', +{ executeid => $executeid, stopcount => $stopcount } ) };
    die "run code $conf->{executer}{name}/stop fail: $@" if $@;
}

sub status
{
    my ( $this, $taskid, $executeid ) = @_;

    my $conf = $this->_config( $taskid );

    my $status = eval{ $this->{ec}->do( $conf->{executer}{name}, 'status', +{ executeid => $executeid } ) };
    die "run code $conf->{executer}{name}/status fail: $@" if $@;
    die "get status error" unless $status && ( $status eq 'running' || $status eq 'stoped' );

    return $status;
}

sub result
{
    my ( $this, $taskid, $executeid ) = @_;

    my $conf = $this->_config( $taskid );

    my $result = eval{ $this->{ec}->do( $conf->{executer}{name}, 'result', +{ executeid => $executeid } ) };
    die "run code $conf->{executer}{name}/status fail: $@" if $@;

    die "get status error" unless defined $result;

    return $result;
}

sub checkparams
{
    my ( $this, $conf ) = @_;

    eval{ $this->{ec}->do( $conf->{name}, 'checkparams', $conf->{param} ) };
    die "run code $conf->{name}/checkparams fail: $@" if $@;
    return;
}

1;
