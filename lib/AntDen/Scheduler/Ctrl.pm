package AntDen::Scheduler::Ctrl;
use strict;
use warnings;

use AntDen::Util::UUID;
use AntDen::Util::Event;
use AntDen::Slave::Executer;

sub new
{
    my ( $class, %this ) = @_;
    map{ die "error $_ undefind" unless $this{$_} }qw( conf code );

    $this{event} = AntDen::Util::Event->new(
        path => "$this{conf}/ctrl/in" );

    $this{executer} = AntDen::Slave::Executer->new(
        code => "$this{code}/executer",
        conf => "$this{conf}/task" );

    bless \%this, ref $class || $class;
}

=head3 startJob( $conf )

  -
    executer: exec
    exec: sleep 100
    scheduler:
      count: 1
      ip: '' #
      envsoft: ''
      envhard: ''
      resources:
        [ CPU, 0, 3 ]
  -
    executer: exec
    exec: sleep 100
    scheduler:
      count: 1
      ip: '' #
      envsoft: ''
      envhard: ''
      resources:
        [ CPU, 0, 3 ]
=cut

sub startJob
{
    my ( $this, $conf, $nice, $group ) = @_;

    die "nice format err" unless defined $nice && $nice =~ /^\d+$/ && $nice >= 0 && $nice <= 9;
    die "group format err" unless defined $group && $group =~ /^[0-9a-zA-Z_-]+$/;
    die "conf err" unless $conf && @$conf > 0;

    my $jobid = AntDen::Util::UUID->new()->jobid();

    for my $config ( @$conf )
    {
        map{ die "$_ undefined.\n" unless $config->{$_} }qw( executer scheduler );

        $config->{scheduler}{count} ||= 1;
        $config->{scheduler}{envsoft} ||= '';
        $config->{scheduler}{envhard} ||= '';

        die "scheduler not Hash.\n" unless ref $config->{scheduler} eq 'HASH';
        my %scheduler = %{$config->{scheduler}};

        die "scheduler.resources err.\n" unless
            defined $scheduler{resources}
         && ref $scheduler{resources} eq 'ARRAY'
         && @{$scheduler{resources}};

        $this->{executer}->checkparams( $config->{executer} );

    }

    $this->{event}->send(
        +{
            jobid => $jobid,
            conf => $conf,
            nice => $nice,
            group => $group,
            ctrl => 'startJob'
        }
    );

    return $jobid;
}

sub stopJob
{
    my ( $this, $jobid ) = @_;
    $this->{event}->send( +{ ctrl => 'stopJob', jobid => $jobid } );
}

sub reniceJob
{
    my ( $this, $jobid, $nice ) = @_;
    die "nice format err" unless defined $nice && $nice =~ /^\d+$/ && $nice >= 0 && $nice <= 9;
    $this->{event}->send( +{ ctrl => 'reniceJob', jobid => $jobid, nice => $nice } );
}

=head3 addMachine ( $conf )

  machine:
    ip: '127.0.0.2'
    hostname: 'local-foo'
    group: 'foo'
    envhard: 'os=Linux,arch=x86_64'
    envsoft: 'web=1.0,app=2.0'
    switchable: 1
    status: 'ok'
  resources:
    'GPU:0': 1
    'GPU:1': 1
    'GPU:2': 1
    'GPU:3': 1
    CPU: 1024
    MEM: 1024

=cut 

sub addMachine
{
    my ( $this, $conf ) = @_;

    map{ die "$_ undef" unless defined $conf->{$_} }qw( machine resources );
    map{ die "machine.$_ undef" unless defined $conf->{machine}{$_} }
        qw( ip hostname group envhard envsoft switchable status );
    die "no resources" unless @{$conf->{resources}};

    $this->{event}->send( +{ %$conf, ctrl => 'addMachine' } );
}

1;
