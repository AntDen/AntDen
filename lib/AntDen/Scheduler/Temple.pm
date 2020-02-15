package AntDen::Scheduler::Temple;
use strict;
use warnings;

use AntDen::Scheduler::Temple::Clotho;

sub new
{
    my ( $class, %this ) = @_;
    map{ die "$_ undef" unless $this{$_} }qw( db conf );
    map{ $this{$_} = +{} }qw( machine resource task stoped );

    $this{temple} = AntDen::Scheduler::Temple::Clotho->new();

    for my $x ( $this{db}->selectMachine() )
    {
        my ( $ip, $hostname, $envhard, $envsoft, $switchable,
            $group, $workable, $role ) = @$x;

        $this{temple}->setMachine(
            $ip => +{
                hostname => $hostname,
                envhard => $envhard,
                envsoft => $envsoft,
                switchable => $switchable,
                group => $group,
                workable => $workable,
                role => $role,
             });
    }

    my ( @r, %r ) = $this{db}->selectResources();
    for my $r ( @r )
    {
        my ( $ip, $name, $id, $value ) = @$r;
        $r{$ip} = [] unless defined $r{$ip};
        push @{$r{$ip}}, [ $name, $id, $value ];
    }
    $this{temple}->setResource( %r ) if %r;

    for( $this{db}->selectJobWork() )
    {
        my ( $id, $jobid, $nice, $group, $status ) = @$_;
        my $jconf = eval{ YAML::XS::LoadFile "$this{conf}/job/$jobid" };
        if( $@ )
        {
            warn "load $this{conf}/job/$jobid fail: $@";
            next;
        }
        my %conf = (
            jobid => $jobid,
            conf => $jconf,
            group => $group,
            nice => $nice,
            status => $status,
        );
        $this{temple}->submitJob( \%conf );
    }

    for ( $this{db}->selectTaskWork() )
    {
        my ( $id, $jobid, $taskid, $hostip, $status, $result, $msg ) = @$_;
        my $tconf = eval{ YAML::XS::LoadFile "$this{conf}/task/$taskid" };
        if( $@ )
        {
            warn "load $this{conf}/task/$taskid fail: $@";
            next;
        }
        my %conf = ( %$tconf, status => $status, result => $result );
        $this{temple}->loadTask( \%conf );
    }

    bless \%this, ref $class || $class;
}

=head3 setMachine( %m )

  ip1:
    hostname: 10-60-79-144
    group: foo
    envhard: arch=x86_64,os=Linux
    envsoft: SELinux=Disabled
    switchable: 1
    workable: 1
    role: slave,ingress,master 

  ip2:
    hostname: 10-60-79-144
    envhard: arch=x86_64,os=Linux
    envsoft: SELinux=Disabled
    switchable: 1
    group: foo
    workable: 1
    role: slave,ingress,master 

=cut

sub setMachine
{
    my ( $this, %m ) = @_;

    for my $ip ( keys %m )
    {
        my  ( %t ) = %{$m{$ip}}; 
        $t{ip} = $ip;
        $this->{db}->insertMachine( 
            map{ defined $t{$_} ? $t{$_} : die "err: nofind $_" }
                @{$this->{db}->column('machine')} );
        $this->{db}->commit();
    }

    $this->{temple}->setMachine( %m );
}

sub setMachineAttr
{
    my ( $this, $ip, $k, $v ) = @_;

    $this->{db}->updateMachineAttr_( $k, $v, $ip );
    $this->{db}->commit();

    $this->{temple}->setMachineAttr( $ip, $k, $v );
}

sub setJobAttr
{
    my ( $this, $jobid, $k, $v ) = @_;

    $this->{db}->updateJobAttr( $k, $v, $jobid );
    $this->{db}->commit();

    $this->{temple}->setJobAttr( $jobid, $k, $v );
}

=head3

 ip1:
  - [ CPU, 0, 2048 ]
  - [ GPU, 0, 1 ]
  - [ GPU, 1, 1 ]
  - [ GPU, 2, 1 ]
  - [ GPU, 3, 1 ]
  - [ MEM, 0, 1839 ]
  - [ PORT, 65000, 1 ]
  - [ PORT, 65001, 1 ]

=cut
sub setResource
{
    my ( $this, %r ) = @_;
    for my $ip ( keys %r )
    {
        $this->{db}->deleteResourcesByIp( $ip );
        map{ $this->{db}->insertResources( $ip, @$_ ) }@{$r{$ip}};
    }
    $this->{db}->commit();
    $this->{temple}->setResource( %r );
}

=head3

  conf:
  -
    executer:
      name: exec
      param:
        exec: echo success
    scheduler:
      count: 10
      envhard: arch=x86_64,os=Linux
      envsoft: app1=1.0
      ip: 127.0.0.1 #
      resources:
        [ GPU, 0, 2 ]
  -
    executer:
      name: exec
      param:
        exec: echo success
    scheduler:
      count: 10
      envhard: arch=x86_64,os=Linux
      envsoft: app1=1.0
      resources:
        [ GPU, 0, 2 ]

  group: foo
  nice: 5
  domain: abc.com
  jobid: J.20200206.114247.252746.499

=cut

sub submitJob
{
    my ( $this, $conf )= @_;

    $this->{db}->insertJob( @$conf{qw( jobid nice group )} );
    $this->{db}->commit();
    eval{ YAML::XS::DumpFile "$this->{conf}/job/$conf->{jobid}", $conf->{conf} };
    die "dump job/$conf->{jobid} fail $@" if $@;

    $this->{temple}->submitJob( $conf );

}
=head3
  -
    taskid: T01
    jobid: J01
    status: success
    result: exit:0
    msg: mesg1
   -
    taskid: T02
    jobid: J01
    status: success
    result: exit:0
    msg: mesg1

=cut

sub taskStatusUpdate
{
    my ( $this, @task, %jobid ) = @_;

    map{
        $jobid{$_->{jobid}}++;
        $this->{db}->updateTaskStatus( @$_{qw( status result msg taskid jobid )} );
    }@task;

    $this->{db}->commit();

    map{ $this->_updateJobStatus( $_ ); }keys %jobid;
}

=head3
  -
    taskid: T01
    jobid: J01
    status: success
    result: exit:0
    msg: mesg1
    usetime: 3
   -
    taskid: T02
    jobid: J01
    status: success
    result: exit:0
    msg: mesg1
    usetime: 3

=cut

sub stoped
{
    my ( $this, @task, %jobid ) = @_;

    map{
        $jobid{$_->{jobid}}++;
        $this->{db}->updateTaskResult( @$_{qw( status result msg usetime taskid jobid )} );
    }@task;

    $this->{db}->commit();

    map{ $this->_updateJobStatus( $_ ); }keys %jobid;

    $this->{temple}->stoped( @task );
}

sub stop
{
    my ( $this, $jobid ) = @_;  
    $this->{stoped}{$jobid} = 1;
    ##TODO save to DB
}

=head3
  -
    jobid: J01
    taskid: T01
    hostip: 127.0.0.1
    resources:
      [ GPU, 0, 2 ]
    executer:
      name: exec
      param:
        exec: echo success
   -
    taskid: T02
    jobid: J01
    hostip: 127.0.0.1
    resources:
      [ GPU, 0, 2 ]
    executer:
      name: exec
      param:
        exec: echo success
 
=cut

sub apply
{
    my ( $this, %jobid, @t ) = shift @_;

    for my $jobid ( keys %{$this->{stoped}} )
    {
        if ( my @task = $this->{temple}->stop( $jobid ) )
        {
            push @t, map{
                +{
                    jobid => $jobid,
                    taskid => $_->{taskid},
                    hostip => $_->{hostip},
                    ctrl => 'stop',
                }
            }@task;
            delete $this->{stoped}{$jobid};
        }
        else
        {
            $this->{db}->JobStoped( $jobid ); #
            $this->{db}->commit();
        }
    }

    return @t unless my $tasks = $this->{temple}->apply();

    for my $t ( @$tasks )
    {
        my ( $jobid, $taskid, $hostip ) = @$t{qw( jobid taskid hostip )};
        $jobid{$jobid} ++;
        $this->{db}->insertTask( $jobid, $taskid, $hostip );
        eval{ YAML::XS::DumpFile "$this->{conf}/task/$taskid", $t };
        die "dump task/$taskid fail $@" if $@;
    }
    $this->{db}->commit();
    map{ $this->_updateJobStatus( $_ ) }keys %jobid;
    return @$tasks, @t;
}

sub _updateJobStatus
{
    my ( $this, $jobid ) = @_;
    my @x = $this->{db}->selectTaskStatusByJobid( $jobid );
    my %x; map{ $x{$_->[0]}++; }@x;
    $this->{db}->updateJobStatus( join( ',', map{ "$_:$x{$_}" } keys %x ),$jobid );
    $this->{db}->commit();
}

1;
