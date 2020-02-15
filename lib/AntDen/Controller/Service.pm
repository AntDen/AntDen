package AntDen::Controller::Service;
use strict;
use warnings;
use Carp;
use YAML::XS;

use AE;

use AntDen::Util::Event;

sub new
{
    my ( $class, %this ) = @_;
    die "conf undef" unless $this{conf};

    ( $this{event1}, $this{event2} )
       = map{ AntDen::Util::Event->new( path => "$this{conf}/ctrl/$_" ) }
           qw( in out );

    $this{hostip} = [];
    if( -f "$this{conf}/slave.ip" )
    {
        $this{hostip} = eval{ YAML::XS::LoadFile "$this{conf}/slave.ip" };
        die "load slave.ip fail: $@" if $@;
        die "slave.ip format error"
            unless defined $this{hostip} && ref $this{hostip} eq 'ARRAY';
    }

    map{ $this{$_} = +{}; }qw( hostevent hostsend );

    bless \%this, ref $class || $class;
}

sub _send
{
    my ( $this, $conf ) = @_;

    die "hostip undef" unless defined $conf->{hostip};
    $this->{hostsend}{$conf->{hostip}} ||= AntDen::Util::Event->new(
        path => "$this->{conf}/slave/$conf->{hostip}/in"
    );

    $this->{hostsend}{$conf->{hostip}}->send( $conf );
}

my $consume = sub
{
    my ( $this, $conf ) = @_;

    YAML::XS::DumpFile \*STDOUT, $conf;

    map{ die "nofind $_" unless $conf->{$_} }qw( ctrl jobid taskid hostip );

    if( $conf->{ctrl} eq 'stop' || $conf->{ctrl} eq 'start' )
    {
         $this->_send( $conf );
    }

    if( $conf->{ctrl} eq 'setHost' )
    {
         die "hostip not array" unless defined $conf->{hostip} && ref $conf->{hostip} eq 'ARRAY';
         eval {YAML::XS::DumpFile "$this->{conf}/slave.ip", $this->{hostip} = $conf->{hostip} };
         die "save slave.ip fail $@" if $@;
    }
};

my $consumeSlave = sub
{
    my ( $this, $conf ) = @_;
    return if $conf->{ctrl} && $conf->{ctrl} eq 'mon';
    YAML::XS::DumpFile \*STDOUT, $conf;
    $this->{event2}->send( $conf );
};

sub run
{
    my $this = shift @_;
    my $cv = AE::cv;

    my $t1 = AnyEvent->timer ( after => 6, interval => 6, cb => sub{

        my %ps; map{
            $ps{$1} ++ if $_ =~ /AntDen_controller_connect_([\d\.]+)_/;
        } `ps -ef|grep AntDen_controller_connect`;

        my %hostip = map{ $_ => 1 }@{$this->{hostip}};

        for ( keys %ps )
        {
            next if $hostip{$_};
            system "killall AntDen_controller_connect_${_}_supervisor";    
            system "killall AntDen_controller_connect_${_}_service";
        }

        my ( $supervisor, $vsync )
            = ( "$MYDan::PATH/dan/tools/supervisor",
               "$AntDen::PATH/controller/tools/vsync" );
        for ( keys %hostip )
        {
            next if $ps{$_};
            my @cmd = 
                (
                    name => "AntDen_controller_connect_${_}_supervisor",
                    host => $_,
                    localpath => "$AntDen::PATH/controller/conf/slave/$_",
                    remote => "$AntDen::PATH/slave/conf/sync",
                    log => "$AntDen::PATH/logs/controller_connect_$_"
                );
            warn "start AntConnect $_ fail: $!" if 
                system sprintf "$supervisor --%s %s --cmd '$vsync --%s %s --%s %s --%s %s' --%s '%s'", @cmd;
        }

        for( keys %{$this->{hostevent}})
        {
            next if $hostip{$_};
            delete $this->{hostevent}{$_};
            delete $this->{hostsend}{$_};
        }

        for( keys %hostip )
        {
            next if $this->{hostevent}{$_};
            $this->{hostevent}{$_} = 
                AntDen::Util::Event->new( path => "$this->{conf}/slave/$_/out" )
                    ->receive( $this, $consumeSlave, hostip => $_ );
        }
    });

    my $t2 = $this->{event1}->receive( $this, $consume );

    $cv->recv;
}

1;
