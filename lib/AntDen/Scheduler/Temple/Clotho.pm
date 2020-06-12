package AntDen::Scheduler::Temple::Clotho;

use strict;
use warnings;

use AntDen::Util::Environment;

sub new
{
    my ( $class, %this ) = @_;
    map{ $this{$_} = +{} }qw( machine job task );
    $this{envmatch} = AntDen::Util::Environment->new();
    bless \%this, ref $class || $class;
}

sub addProduct
{
    my ( $this, $conf ) = @_;
    $this->{product}{$conf->{conf}{id}} = $conf;
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
    mon: health=1,load=0.1

  ip2:
    hostname: 10-60-79-144
    envhard: arch=x86_64,os=Linux
    envsoft: SELinux=Disabled
    switchable: 1
    group: foo
    workable: 1
    role: slave,ingress,master 
    mon: health=1,load=0.1

=cut

sub setMachine
{
    my ( $this, %m ) = @_;
    for my $ip ( keys %m )
    {
        map{ die "$_ undef" unless defined $m{$ip}{$_} }
            qw( hostname envhard envsoft switchable group workable role );
        $this->{machine}{$ip}{info} = $m{$ip};
    }
    return sort keys %{$this->{machine}};
}

sub setMachineAttr
{
    my ( $this, $ip, $k, $v ) = @_;
    $this->{machine}{$ip}{info}{$k} = $v;
}

sub setJobAttr
{
    my ( $this, $jobid, $k, $v ) = @_;
    $this->{job}{$jobid}{info}{$k} = $v;
}

=head3

 ip1:
  - [ CPU, 0, 2048 ]
  - [ GPU, 0, 1 ]
  - [ GPU, 1, 1 ]
  - [ MEM, 0, 1839 ]
  - [ PORT, 65000, 1 ]
  - [ PORT, 65001, 1 ]

=cut

sub setResource
{
    my ( $this, %r ) = @_;
    for my $ip ( keys %r )
    {
        die "$_ undef" unless $r{$ip} && ref $r{$ip} eq 'ARRAY';
        map{ die "err" unless  @$_ == 3 }@{$r{$ip}};
        $this->{machine}{$ip}{resources} = $r{$ip};
    }
}

=head3
  -
    jobid: J01
    taskid: T01
    status: stoped
    hostip: 127.0.0.1
    executer: ~
    resources:
      - [ CPU, 0, 2048 ]
      - [ GPU, 0, 1 ]
   -
    jobid: J01
    taskid: T02
    status: stoped
    hostip: 127.0.0.1
    executer: ~
    resources:
      - [ CPU, 0, 2048 ]
      - [ GPU, 0, 1 ]
=cut

sub loadTask
{
    my ( $this, @task ) = @_;
    for my $task ( @task )
    {
        $this->{machine}{$task->{hostip}}{task}{$task->{taskid}} = $task->{resources}; 
        $this->{job}{$task->{jobid}}{task}{$task->{taskid}} = $task;
        $this->{task}{$task->{taskid}} = $task->{jobid};
    }
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
  owner: root
  name: job.abc

=cut

sub submitJob
{
    my ( $this, $conf ) = @_;
    $this->{job}{$conf->{jobid}}{info} = $conf;
}

=head3
    J.0
=cut


sub stop
{
    my ( $this, $jobid ) = @_;

    if( defined $this->{job}{$jobid}{task} && keys %{$this->{job}{$jobid}{task}} )
    {
        return map{
                   +{ taskid => $_, hostip => $this->{job}{$jobid}{task}{$_}{hostip} }
               }keys %{$this->{job}{$jobid}{task}};
    }
    else
    {
        delete $this->{job}{$jobid};
        return;
    }
}

=head3
  -
    taskid: T01
    jobid: J01
    status: success
    result: exit:0
#    msg: mesg1
#    usetime: 3
   -
    taskid: T02
    jobid: J01
    status: success
    result: exit:0
    msg: mesg1
    usetime: 3
=cut


##TODO
sub stoped
{
    my ( $this, @task ) = @_;
    for my $task ( @task )
    {
        next unless my $hostip = $this->{job}{$task->{jobid}}{task}{$task->{taskid}}{hostip};

        delete $this->{job}{$task->{jobid}}{task}{$task->{taskid}};
        delete $this->{machine}{$hostip}{task}{$task->{taskid}};

        delete $this->{task}{$task->{taskid}};
        delete $this->{job}{$task->{jobid}} unless keys %{$this->{job}{$task->{jobid}}{task}};
    }
}

=head3
output =>
  -
    jobid: J01
    taskid: T01
    hostip: 127.0.0.1
    resources:
      [ GPU, 0, 2 ]
    executer:
      param: ~
      name: exec
   -
    taskid: T02
    jobid: J01
    hostip: 127.0.0.1
    resources:
      [ GPU, 0, 2 ]
    executer:
      param: ~
      name: exec


input =>
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
  jobid: J.20200206.114247.252746.499

=cut

sub apply
{
    my $this = shift @_;
    my %group; map{ $group{$_->{info}{group}} = [] }grep{ $_->{info} }values %{$this->{machine}};

    for my $jobid ( sort keys %{$this->{job}} )
    {
        next unless $this->{job}{$jobid}{info} && $group{$this->{job}{$jobid}{info}{group}};
        next if keys %{$this->{job}{$jobid}{task}};
        push @{$group{$this->{job}{$jobid}{info}{group}}}, $jobid;
    }

    my @conf;
    for my $group ( keys %group )
    {
        my $rid;
        for my $jobid ( @{$group{$group}} )
        {
            $rid = $jobid unless $rid;
            $rid = $jobid if
                $this->{job}{$rid}{info}{nice} > $this->{job}{$jobid}{info}{nice};
        }
        next unless $rid;
        next unless my @c = $this->_applyByJobid( $rid );
        push @conf, @c;
    }

    return @conf;
}

=head3
output =>
  -
    jobid: J01
    taskid: T01
    hostip: 127.0.0.1
    resources:
      [ GPU, 0, 2 ]
    executer:
      param: ~
      name: exec
   -
    taskid: T02
    jobid: J01
    hostip: 127.0.0.1
    resources:
      [ GPU, 0, 2 ]
    executer:
      param: ~
      name: exec


input =>
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
  jobid: J.20200206.114247.252746.499

=cut

sub _applyByJobid
{
    my ( $this, $jobid ) = @_;
    return unless my $conf = $this->{job}{$jobid}{info}{conf};

    map{
        $this->{machine}{$_}{temp} = +{};
        $this->{machine}{$_}{task} ||= +{};
    }keys %{$this->{machine}};
    my ( $id, @conf ) = ( 1 );

    for my $conf ( @$conf )
    {
        for( 1 .. $conf->{scheduler}{count} )
        {
            my ( $hostip, $res ) = $this->_search(
                $this->{job}{$jobid}{info}{group},
                $conf->{scheduler}{envhard},
                $conf->{scheduler}{envsoft},
                $conf->{scheduler}{resources},
                $conf->{scheduler}{ip}
            );
            return unless defined $hostip;

            my $taskid = sprintf "%s.%03d", $jobid, $id ++;
            $taskid =~ s/J/T/;

            my $c = +{ 
                taskid => $taskid,
                jobid => $jobid,
                hostip => $hostip,
                resources => $res,
                executer => $conf->{executer},
                ingress => $conf->{ingress},
                group => $this->{job}{$jobid}{info}{group},
            };
            push @conf, $c;

            $this->{job}{$jobid}{task}{$taskid} = $c;
            $this->{task}{$jobid} = $taskid;
            $this->{machine}{$hostip}{temp}{$taskid} = $res;
        }
    }

    map{ 
        %{$this->{machine}{$_}{task}} =
            ( %{$this->{machine}{$_}{task}}, %{$this->{machine}{$_}{temp}} );
    }keys %{$this->{machine}};

    return @conf;
}

sub _search
{
    my ( $this, $group, $envhard, $envsoft, $resources, $ip ) = @_;

    my @host = grep{ $this->{machine}{$_}{info}{group} eq $group }
               grep{ $this->{machine}{$_}{info}{role} eq 'slave'  }
               grep{ $this->{machine}{$_}{info}{mon} =~ /health=1/  }
               grep{ $this->{machine}{$_}{info} }keys %{$this->{machine}};

    @host = grep{ $_ eq $ip }@host if defined $ip;

#    @host = grep{ $this->_matchEnv( $this->{machine}{$_}{info}{envhard}, $envhard ) }@host;
#    @host = grep{ $this->_matchEnv( $this->{machine}{$_}{info}{envhard}, $envsoft ) }@host;

    my %h;
    for my $host ( @host )
    {
        next unless my $r = $this->_matchResources( $host, $resources );
        $h{$host} = $r;
    }
    return unless keys %h;

    my $h = ( sort{ $this->_tasklen( $a ) <=> $this->_tasklen( $b ) } keys %h )[0];
    
    return ( $h, $h{$h} );
}

sub _matchResources
{
    my ( $this, $host, $resources, @res ) = @_;

    my @hostResources = @{$this->{machine}{$host}{resources}};
    my @usedResources = map{ @$_ }values %{$this->{machine}{$host}{task}};
    push @usedResources, map{ @$_ }values %{$this->{machine}{$host}{temp}};
    
    my %hostResources;
    for ( @hostResources )
    {
        my ( $name, $k, $v ) = @$_;
        $hostResources{$name}{$k} = $v;
    }

    for ( @usedResources )
    {
        my ( $name, $k, $v ) = @$_;
        $hostResources{$name}{$k} -= $v;
    }
    
    for ( @$resources )
    {
        my ( $name, $k, $v ) = @$_;
        if( $k eq '.' )
        {
            my $match;
            my $x = $hostResources{$name};
            for my $tmp ( keys %$x )
            {
                if( $x->{$tmp} >= $v )
                {
                    push @res, [ $name, $tmp, $v ];
                    $hostResources{$name}{$tmp} -= $v;
                    $match = 1;
                    last;
                }
            }
            return unless $match;
        }
        else
        {
            if ( $hostResources{$name}{$k} && $hostResources{$name}{$k} >= $v )
            {
                push @res, [ $name, $k, $v ];
                $hostResources{$name}{$k} -= $v;
            }
            else
            {
                return;
            }
        }
    }

    return \@res;
}

sub _tasklen
{
    my ( $this, $ip ) = @_;
    return keys( %{$this->{machine}{$ip}{task}} ) + keys( %{$this->{machine}{$ip}{temp}} );
}

sub _matchEnv
{
    my ( $this, $env1, $env2 ) = @_;
    return $this->{envmatch}->match( $env1, $env2 ); 
}
1;
