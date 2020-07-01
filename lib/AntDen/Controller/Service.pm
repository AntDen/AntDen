package AntDen::Controller::Service;
use strict;
use warnings;
use Carp;
use YAML::XS;
use AE;

sub new
{
    my ( $class, %this ) = @_;
    die "conf undef" unless $this{conf};
    $this{hostip} = [];
    bless \%this, ref $class || $class;
}

sub run
{
    my $this = shift @_;
    my $cv = AE::cv;

    my $t1 = AnyEvent->timer ( after => 1, interval => 6, cb => sub{
        my $hostip = eval{ YAML::XS::LoadFile "$this->{conf}/slave.ip" };
        warn "load slave.ip fail: $@" if $@;
        $this->{hostip} = $hostip if $hostip && ref $hostip eq 'ARRAY';
    });

    my $t2 = AnyEvent->timer ( after => 6, interval => 6, cb => sub{

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
            system "mkdir -p '$AntDen::PATH/controller/conf/slave/$_/in'";
            system "ln -fsn ../../../../scheduler/conf/ctrl/in $AntDen::PATH/controller/conf/slave/$_/out";
            warn "start AntConnect $_ fail: $!" if 
                system sprintf "$supervisor --count 3 --%s %s --cmd '$vsync --%s %s --%s %s --%s %s' --%s '%s'", @cmd;
        }
    });

    $cv->recv;
}

1;
