package AntDen::Scheduler::Service;
use strict;
use warnings;
use YAML::XS;
use AE;

use AntDen;
use AntDen::Util::Event;
use AntDen::Scheduler::DB;
use AntDen::Controller::Ctrl;
use AntDen::Scheduler::Temple;
use AntDen::Scheduler::Mon;
use AntDen::Scheduler::Log;
our %machinegroup;

sub new
{
    my ( $class, %this ) = @_;
    map{ die "error $_ undefind" unless $this{$_} }qw( db conf temple );

    $this{db} = AntDen::Scheduler::DB->new( $this{db} );

    $this{event} = AntDen::Util::Event->new(
        path => "$this{conf}/ctrl/in" );

    $this{log} = AntDen::Scheduler::Log->new(
        path => "$AntDen::PATH/logs/monitor",
        name => 'scheduler' );

    $this{a} = AntDen::Scheduler::Temple->new(
        map{ $_ => $this{$_} }qw( db conf temple ) );

    $this{mon} = AntDen::Scheduler::Mon->new( a => $this{a} );
    bless \%this, ref $class || $class;
}

my $consume = sub
{
    my ( $this, $conf ) = @_;

    die "nofind ctrl" unless $conf->{ctrl};
    YAML::XS::DumpFile \*STDOUT, $conf if $conf->{ctrl} ne 'mon';

    if( $conf->{ctrl} eq 'addMachine' )
    {
        $this->{a}->setMachine( $conf->{machine}{ip} => $conf->{machine} );
        $this->{a}->setResource( $conf->{machine}{ip} => $conf->{resources} );
        AntDen::Controller::Ctrl->new( %{$this->{controller}} )->dumpMachine( $this->{a}->getMachine() );
    }
    if( $conf->{ctrl} eq 'startJob' )
    {
        $this->{a}->submitJob( $conf );
    }
    if( $conf->{ctrl} eq 'stopJob' )
    {
        $this->{a}->stop( $conf->{jobid} );
    }
    if( $conf->{ctrl} eq 'reniceJob' )
    {
        $this->{a}->setJobAttr( $conf->{jobid}, 'nice', $conf->{nice} );
    }

    if( $conf->{ctrl} eq 'taskStatus' )
    {
        map{ die "$_ undef" unless defined $conf->{$_} }
            qw( status result msg taskid jobid );
        $this->{a}->taskStatusUpdate( $conf );
    }

    if( $conf->{ctrl} eq 'taskResult' )
    {
        map{ die "$_ undef" unless defined $conf->{$_} }
            qw( status result msg taskid jobid usetime );
        $this->{a}->stoped( $conf );
    }
    if( $conf->{ctrl} eq 'mon' )
    {
        map{ die "$_ undef" unless defined $conf->{$_} } qw( health hostip );
        $this->{log}->say( +{ %$conf, group => $machinegroup{$conf->{hostip}} } );
        $this->{mon}->add( $conf );
    }

};

sub run
{
    my $this = shift;

    my $cv = AE::cv;

    my $c = AntDen::Controller::Ctrl->new( %{$this->{controller}} );

    my $t1 = AnyEvent->timer ( after => 1, interval => 1, cb => sub{
        map{
            $_->{ctrl} && $_->{ctrl} eq 'stop'
            ? $c->stop( $_ ) : $c->start( $_ );
        }$this->{a}->apply();
    });

    my $t2 = AnyEvent->timer ( after => 3, interval => 3, cb => sub{
        $this->{mon}->save( $this->{a}->getMachine() );
    });

    my $t3 = AnyEvent->timer ( after => 60, interval => 60, cb => sub{
        $this->{log}->cut();
    });

    my $t4 = $this->{event}->receive( $this, $consume );

    my %cachefile;
    my $t5 = AnyEvent->timer ( after => 6, interval => 60, cb => sub{
        my %file;
        map{
            push @{$file{$_->[4]}},
                +{ name => $_->[1], info => $_->[2],
                   type => $_->[3], group => $_->[4], token => $_->[5]
            };
        }$this->{db}->selectDatasets();
        map{ $file{$_} = YAML::XS::Dump $file{$_}  }keys %file;

        for my $machine ( $this->{a}->getMachineDetail() )
        {
            $machinegroup{$machine->{ip}} = $machine->{group};
            next unless $machine->{mon} =~ /health=1/;
            my $cont = $file{$machine->{group}} || '';
            next if defined $cachefile{$machine->{ip}} && $cachefile{$machine->{ip}}{cont} eq $cont;
            $cachefile{$machine->{ip}} = +{ cont => $cont, time => time + 60 };
            $c->file( +{ jobid => 'j.0', taskid => 't.0',
                hostip => $machine->{ip}, cont => $cont,
                path => "$AntDen::PATH/slave/conf/datasets.conf"
            });
        }
    });

    my $t6 = AnyEvent->timer ( after => 6, interval => 6, cb => sub{
        my ( $i, $time ) = ( 0, time );
        for my $ip ( keys %cachefile )
        {
             delete $cachefile{$ip} if $cachefile{$ip}{time} < $time;
             #last if $i ++ >= 3;
        }
    });
    $cv->recv;
}
1;
