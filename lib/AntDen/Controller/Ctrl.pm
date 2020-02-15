package AntDen::Controller::Ctrl;
use strict;
use warnings;
use Carp;
use YAML::XS;

use AntDen::Util::Event;

sub new
{
    my ( $class, %this ) = @_;

    die "error conf undefind" unless $this{conf};

    $this{event} = AntDen::Util::Event->new(
        path => "$this{conf}/ctrl/in"
    );

    bless \%this, ref $class || $class;
}

=head3 start( $conf )

  jobid: J.0
  taskid: T.0
  hostip: 127.0.0.1
  resources:
    - [ CPU, 0, 2  ]
  executer:
    param:
      exec: sleep 100
    name: exec
    
=cut

sub start
{
    my $this = shift  @_;
    for my $conf ( @_ )
    {
        map{ die "nofind $_" unless $conf->{$_} }
            qw( taskid hostip resources executer );
        $conf->{jobid} ||= 'J.0';
        $this->{event}->send( +{ %$conf, ctrl => 'start' } );
    }
}

=head3 stop( $conf )

  taskid: T.0
  jobid: J.0

=cut

sub stop
{
    my $this = shift @_;
    for my $conf ( @_ )
    {
        map{ die "nofind $_" unless $conf->{$_} } qw( taskid hostip );
        $conf->{jobid} ||= 'J.0';
        $this->{event}->send( +{ %$conf, ctrl => 'stop' } );
    }
}

sub dumpMachine
{
    my $this = shift  @_;
    $this->{event}->send( +{ hostip => \@_, ctrl => 'setHost' } );
}

1;
