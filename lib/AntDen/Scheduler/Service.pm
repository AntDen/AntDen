package AntDen::Scheduler::Service;
use strict;
use warnings;
use YAML::XS;
use AE;

use AntDen::Util::Event;
use AntDen::Scheduler::DB;
use AntDen::Controller::Ctrl;
use AntDen::Scheduler::Temple;

sub new
{
    my ( $class, %this ) = @_;
    map{ die "error $_ undefind" unless $this{$_} }qw( db conf );

    $this{db} = AntDen::Scheduler::DB->new( $this{db} );

    $this{event} = AntDen::Util::Event->new(
        path => "$this{conf}/ctrl/in" );

    $this{a} = AntDen::Scheduler::Temple->new(
        db => $this{db}, conf => $this{conf} );

    bless \%this, ref $class || $class;
}

my $consume = sub
{
    my ( $this, $conf ) = @_;

    die "nofind ctrl" unless $conf->{ctrl};
    YAML::XS::DumpFile \*STDOUT, $conf;

    if( $conf->{ctrl} eq 'addMachine' )
    {
        $this->{a}->setMachine( $conf->{machine}{ip} => $conf->{machine} );
        $this->{a}->setResource( $conf->{machine}{ip} => $conf->{resources} );
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

    my $t2 = $this->{event}->receive( $this, $consume );

    $cv->recv;
}
1;
