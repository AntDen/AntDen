package AntDen::Scheduler::Ingress;
use strict;
use warnings;

use AntDen::Util::UUID;

sub new
{
    my ( $class, %this ) = shift @_;
    map{ $this{$_} = +{} }qw( task ingress machine );
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
    $this->{machine} = +{ %{$this->{machine}}, %m };
}

sub setMachineAttr
{
    my ( $this, $ip, $k, $v ) = @_;
    $this->{machine}{$ip}{$k} = $v;
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
    my ( $this ) = shift @_;
    map{ $this->{task}{$_->{taskid}} = $_; }@_;
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
    my ( $this, @task ) = @_;

    map{
        $this->{task}{$_->{taskid}}{status} = $_->{status};
        my $ingress =  $this->{task}{$_->{taskid}}{ingress};
        $this->{ingress}{$ingress->{domain}} = 1
            if $ingress && ref $ingress eq 'HASH' && $ingress->{domain};
    }@task;
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
    my ( $this, @task ) = @_;

    map{
        delete $this->{task}{$_->{taskid}};
        my $ingress =  $this->{task}{$_->{taskid}}{ingress};
        $this->{ingress}{$ingress->{domain}} = 1 if $ingress && ref $ingress eq 'HASH';
    }@task;
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
    my ( $this, @task ) = shift @_;

    for my $domain ( keys %{$this->{ingress}} )
    {
        push @task, $this->_ingress( $domain );
        delete $this->{ingress}{$domain};
    }

    return @task;
}

sub _ingress
{
    my ( $this, $domain, %group ) = splice @_, 0, 2;

    for my $t ( values %{$this->{task}} )
    {
        $group{$t->{group}} ++ if $t->{ingress}{domain} && $t->{ingress}{domain} eq $domain;
    }

    return map{ $this->_ingressByGroup( $domain, $_ ); }keys %group;
}

sub _ingressByGroup
{
    my ( $this, $domain, $group, %location, @host, @t ) = splice @_, 0, 3;

    for my $task ( grep{ defined $_->{group} && $_->{group} eq $group }values %{$this->{task}} )
    {
        next unless $task->{ingress} && $task->{ingress}{domain} && $task->{ingress}{domain} eq $domain;
        map{ push( @{$location{$task->{ingress}{location}}}, "$task->{hostip}:$_->[1]" ) if $_->[0] eq 'PORT'; }@{$task->{resources}};
    }

    for my $ip ( keys %{$this->{machine}} )
    {
        push( @host, $ip ) if $this->{machine}{$ip}{role} eq 'ingress' && $this->{machine}{$ip}{group} eq $group;
    }

    for my $host ( @host )
    {
        push @t, +{
            taskid => AntDen::Util::UUID->new()->taskid(),
            jobid => 'J0',
            hostip => $host,
            resources => [],
            executer => +{
                name => 'nginx',
                param => +{
                    domain => $domain,
                    location => \%location,
                }

            },
            group => $group,
        };
    }
    return @t;
}

1;
