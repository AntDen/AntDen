package AntDen::Scheduler::Temple;
use strict;
use warnings;

use AntDen::Scheduler::Ingress;
use AntDen::Scheduler::Temple::Clotho;

sub new
{
    my ( $class, %this ) = @_;
    map{ die "$_ undef" unless $this{$_} }qw( db conf );
    map{ $this{$_} = +{} }qw( stoped );

    $this{ingress} = AntDen::Scheduler::Ingress->new();
    $this{temple} = AntDen::Scheduler::Temple::Clotho->new();

    for my $x ( $this{db}->selectMachine() )
    {
        my ( $ip, $hostname, $envhard, $envsoft, $switchable,
            $group, $workable, $role ) = @$x;

        my $hi = +{
            hostname => $hostname,
            envhard => $envhard,
            envsoft => $envsoft,
            switchable => $switchable,
            group => $group,
            workable => $workable,
            role => $role,
         };
        $this{ingress}->setMachine( $ip => $hi );
        $this{temple}->setMachine( $ip => $hi );
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

        $this{ingress}->loadTask( \%conf );
        $this{temple}->loadTask( \%conf ) if $conf{jobid} ne 'J0';
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
        $t{mon} = 'health=0';
        $this->{db}->insertMachine( 
            map{ defined $t{$_} ? $t{$_} : die "err: nofind $_" }
                @{$this->{db}->column('machine')} );
        $this->{db}->commit();
    }

    $this->{ingress}->setMachine( %m );
    $this->{temple}->setMachine( %m );
}

sub setMachineAttr
{
    my ( $this, $ip, $k, $v ) = @_;

    $this->{db}->updateMachineAttr_( $k, $v, $ip );
    $this->{db}->commit();

    $this->{ingress}->setMachineAttr( $ip, $k, $v );
    $this->{temple}->setMachineAttr( $ip, $k, $v );
}

sub setJobAttr
{
    my ( $this, $jobid, $k, $v ) = @_;

    $this->{db}->updateJobAttr_( $k, $v, $jobid );
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
    my ( $this, $conf, %ingress ) = splice @_, 0, 2;

    for my $c ( @{$conf->{conf}} )
    {
        next unless my $i = $c->{ingress};
        next unless ref $i eq 'HASH' && defined $i->{domain} && defined $i->{location};
        $ingress{"$i->{domain}:$i->{location}"} ++;
    }

    $this->{db}->insertJob( @$conf{qw( jobid nice group )}, join ',', keys %ingress );
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
    $this->{ingress}->taskStatusUpdate( @task );
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

    $this->{ingress}->stoped( @task );
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
    my ( $this, %jobid, @t, @task ) = shift @_;

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
            $this->{db}->jobStoped( $jobid ); #
            $this->{db}->commit();
        }
    }

    push @task, $this->{ingress}->apply();
    push @task, $this->{temple}->apply();

    return @t unless @task;

    for my $t ( @task )
    {
        my ( $jobid, $taskid, $hostip, $ingress, $resources )
            = @$t{qw( jobid taskid hostip ingress resources )};

        $this->{ingress}->loadTask( +{ %$t, status => 'init' } );

        $jobid{$jobid} ++;

        my ( $domain, $location, $port ) = ( '', '', '' );
        my @port; map{ push @port, $_->[1] if $_->[0] eq 'PORT'; }@$resources;
        $port = join ',', @port if @port;

        ( $domain, $location ) = ( $ingress->{domain}, $ingress->{location} )
            if ref $ingress eq 'HASH' && defined $ingress->{domain} && defined $ingress->{location};

        $this->{db}->insertTask( $jobid, $taskid, $hostip, $domain, $location, $port );
        eval{ YAML::XS::DumpFile "$this->{conf}/task/$taskid", $t };
        die "dump task/$taskid fail $@" if $@;
    }
    $this->{db}->commit();
    map{ $this->_updateJobStatus( $_ ) }keys %jobid;
    return @task, @t;
}

sub _updateJobStatus
{
    my ( $this, $jobid ) = @_;
    my @x = $this->{db}->selectTaskStatusByJobid( $jobid );
    my %x; map{ $x{$_->[0]}++; }@x;
    $this->{db}->updateJobStatus( ( 1 == keys %x ) ? $x[0][0]: join( ',', map{ "$_:$x{$_}" } keys %x ), $jobid );
    $this->{db}->commit();
}

1;
