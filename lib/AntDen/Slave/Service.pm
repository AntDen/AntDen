package AntDen::Slave::Service;
use strict;
use warnings;
use Carp;
use YAML::XS;

use AE;
use POSIX qw( :sys_wait_h );
use Sys::Hostname;
use File::Basename;

use AntDen;
use AntDen::Slave;
use AntDen::Slave::DB;
use AntDen::Slave::Monitor;
use AntDen::Slave::Executer;
use AntDen::Util::Event;

our %status2id = %AntDen::Slave::status2id;
our %id2status = %AntDen::Slave::id2status;

use constant { LIMIT => 1000 };
our %tasktimeout;

sub new
{
    my ( $class, %this ) = @_;

    map{ die "$_ undef" unless $this{$_} }qw( db conf code );

    $this{executer} = AntDen::Slave::Executer->new( 
        conf => "$this{conf}/task",
        code => "$this{code}/executer",
    );

    $this{monitor} = AntDen::Slave::Monitor->new( 
        path => "$this{code}/monitor"
    );

    $this{db} = AntDen::Slave::DB->new( $this{db}, 1 );

    ( $this{event1}, $this{event2} )
        = map{
            AntDen::Util::Event->new( path => "$this{conf}/ctrl/$_" )
        }qw( in out );

    bless \%this, ref $class || $class;
}

my $consume = sub
{
    my ( $this, $conf ) = @_;

    YAML::XS::DumpFile \*STDOUT, $conf;
    map{ die "$_ undef" unless $conf->{$_} }qw( ctrl taskid jobid );

    if( $conf->{ctrl} eq 'stop' )
    {
        $this->{db}->stopTask( $status2id{stoped}, $conf->{taskid} );
    }

    if( $conf->{ctrl} eq 'start' )
    {
        unless( -f "$this->{conf}/task/$conf->{taskid}" )
        {
            eval{ YAML::XS::DumpFile "$this->{conf}/task/$conf->{taskid}", $conf };
            die "dump config fail $@" if $@;
        }
        eval{
            $this->{db}->startTask(
                $conf->{jobid} || 'J.0',
                $conf->{taskid}, $status2id{init}, $status2id{running}, time,
                $conf->{taskid} =~ /^t/ ? LIMIT : 1 ); };
        warn "insert task fail: $@\n" if $@;
    }
};

sub run
{
    my $this = shift;

    my $cv = AE::cv;

    my ( $db, $executer ) = @$this{qw( db executer )};

    my $monitor = AnyEvent->timer ( after => 1, interval => 1, cb => sub{
            $this->monitorDump( $this->{monitor}->do() );
        });

    my $t1 = $this->{event1}->receive( $this, $consume );
   
    my $t2 = AnyEvent->timer ( after => 1, interval => 1, cb => sub{

        my ( $weightc, @task ) = ( 0, $db->selectTask() );

        for ( @task )
        {
            my ( $jobid, $taskid, $status, $expect, $executeid, $weight ) = @$_;
             $weightc += $weight;
             last if $weightc > LIMIT;

            my $statusDump;
            if( $id2status{$status} eq 'init' )
            {
                if( $id2status{$expect} eq 'stoped' )
                {
                    $db->updateTaskStatus( $status2id{stoped}, $taskid );
                    $statusDump = 1;
                }
                else
                {
                    $tasktimeout{$taskid}{starting} = time + 60;

                    $db->updateTaskStatus( $status2id{starting}, $taskid );
                    $statusDump = 1;

                    $status = $status2id{starting};

                    $executeid = eval{ $executer->start( $taskid ) };

                    if( ref $executeid )
                    {
                        $db->updateTaskSR( $status2id{stoped}, $executeid->{result} || '',  $taskid );

                        $this->resultDump( $taskid );
                        $db->deleteTask( $taskid );
                        delete $tasktimeout{$taskid};
                        last;
                    }
                    if ( $@ )
                    {
                        warn "start tsak fail: $@";
                        $db->updateTaskMsg( 'start tsak fail', $taskid );
                        $this->statusDump( $taskid );
                        next;
                    }

                    $db->updateExecuteid( $executeid, $status2id{running}, $taskid );
                }
            }

            if( $id2status{$status} eq 'starting' )
            {
                unless( $executeid )
                {
                    $db->updateTaskMsg( 'no executeid', $taskid );
                    $db->updateTaskStatus( $status2id{stoped}, $taskid );
                    $this->statusDump( $taskid );
                    next;
                }

                my $tstatus = eval{ $executer->status( $taskid, $executeid ); };
                if( $@ )
                {
                    warn "get tsak status fail: $@";
                    $db->updateTaskMsg( 'get task status fail', $taskid );
                    $this->statusDump( $taskid );
                    next;
                }

                if( $tstatus eq 'running' )
                {
                    $db->updateTaskStatus( $status2id{running}, $taskid );
                    $statusDump = 1;
                }
                else{
                    if( $tasktimeout{$taskid}{starting} < time )
                    {
                        $db->updateTaskStatus( $status2id{stoped}, $taskid );
                        $db->updateTaskMsg( 'start timeout', $taskid );
                        $statusDump = 1;
                    }
                }
            }

            if( $id2status{$status} eq 'running' )
            {
                if( $id2status{$expect} eq 'running' )
                {
                    my $tstatus = eval{ $executer->status( $taskid, $executeid ); };
                    if( $@ )
                    {
                        warn "get tsak status fail: $@";
                        $db->updateTaskMsg( 'get task status fail', $taskid );
                        $this->statusDump( $taskid );
                        next;
                    }
                    if( $tstatus eq 'stoped' )
                    {
                        $db->updateTaskStatus( $status2id{stopping}, $taskid );
                        $statusDump = 1;

                        $status = $status2id{stopping};
                    }

                }
                else
                {
                    $tasktimeout{$taskid}{stopping} = time + 60;

                    $db->updateTaskStatus( $status2id{stopping}, $taskid );
                    $statusDump = 1;


                    $status = $status2id{stopping};
                }
            }

            if( $id2status{$status} eq 'stopping' )
            {
                eval{ $executer->stop( $taskid, $executeid ) };
                if( $@ )
                {
                    $db->updateTaskMsg( 'stopping code err', $taskid );
                    $this->statusDump( $taskid );
                    next;
                }

                my $tstatus = eval{ $executer->status( $taskid, $executeid ); };
                if( $@ )
                {
                    warn "get tsak status fail: $@";
                    $db->updateTaskMsg( 'get task status fail', $taskid );
                    $this->statusDump( $taskid );
                    next;
                }

                if( $tstatus eq 'stoped' )
                {
                    $db->updateTaskStatus( $status2id{exiting}, $taskid );
                    $statusDump = 1;

                    $status = $status2id{exiting};
                }
            }

            if( $id2status{$status} eq 'exiting' )
            {
                my $result = eval{ $executer->result( $taskid, $executeid ); };
                if( $@ )
                {
                    warn "get tsak status fail: $@";
                    $db->updateTaskMsg( 'get task status fail', $taskid );
                    $this->statusDump( $taskid );
                    next;
                }

                $db->updateTaskStatus( $status2id{stoped}, $taskid );
                $db->updateTaskResult( $result, $taskid );
                $status = $status2id{stoped};
                $statusDump = 1;
            }

            if( $id2status{$status} eq 'stoped' )
            {
                $this->resultDump( $taskid );
                $db->deleteTask( $taskid );
                delete $tasktimeout{$taskid};
                next;
            }
            $this->statusDump( $taskid ) if $statusDump;
 
        }
    });

    $cv->recv;
}

sub statusDump
{
    my ( $this, $taskid ) = @_;
    $this->_rsDump( $taskid, 'taskStatus' );
}

sub resultDump
{
    my ( $this, $taskid ) = @_;
    $this->_rsDump( $taskid, 'taskResult' );
}

sub _rsDump
{
    my ( $this, $taskid, $ctrl ) = @_;

    return unless my @r = $this->{db}->selectTaskByTaskid( $taskid );
    my $r = +{
        jobid => $r[0][0],
        status => $id2status{$r[0][1]},
        result => $r[0][2],
        msg => $r[0][3],
        taskid => $taskid,
        ctrl => $ctrl,
    };
    $r->{usetime} = time - $r[0][4] if $ctrl eq 'taskResult';
    $this->{event2}->send( $r );
}

sub monitorDump
{
    my ( $this, $data ) = @_;
    $this->{event2}->send( +{ %$data, ctrl => 'mon' } );
}

1;
