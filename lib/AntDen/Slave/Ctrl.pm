package AntDen::Slave::Ctrl;
use strict;
use warnings;
use Carp;
use YAML::XS;

use Sys::Hostname;
use File::Basename;

use AntDen;
use AntDen::Util::Event;

sub new
{
    my ( $class, %this ) = @_;

    die "conf undef" unless $this{conf};

    $this{event} = AntDen::Util::Event->new(
        path => "$this{conf}/ctrl/in" );

    bless \%this, ref $class || $class;
}

=head3 start( $conf )

  taskid: T.0
  jobid: J.0
  resources:
    - [ CPU, 0, 1 ]
  executer:
    param:
      exec: sleep 100
    name: exec

=cut

sub start
{
    my ( $this, $conf ) = @_;
    map{ die "$_ undef" unless $conf->{$_}; }
        qw( taskid resources executer );
    $conf->{jobid} ||= 'J.0';
    $this->{event}->send( +{ %$conf, ctrl => 'start' } );
}

=head3 stop( $conf )

    taskid: T.0
    jobid: J.0

=cut

sub stop
{
    my ( $this, $conf ) = @_;
    die "taskid undef" unless $conf->{taskid};
    $conf->{jobid} ||= 'J.0';
    $this->{event}->send( +{ %$conf, ctrl => 'stop' } );
}

sub info
{
    my ( $this, @res, %env ) = shift;

    for my $name ( sort grep{ -f }glob "$this->{code}/resources/*" )
    {
        my $code = do $name;
        die "load code $name fail\n" unless $code && ref $code eq 'CODE';
        my $data = &$code();

        $data = [ [ 'x', $data ] ] unless ref $data eq 'ARRAY';
        map{ push @res, [ basename($name), @$_ ]; }@$data; 
    }

    for my $type ( qw( hard soft ) )
    {
        map{
            my $name = basename $_;
            my $code = do ( $type eq 'soft' ? "$_/get" : $_ );
            $env{$type}{$name} = &$code();
        }glob "$this->{code}/executer/environment/plugin/$type/*";

        $env{"env$type"} = join ',', 
            map{ "$_=$env{$type}{$_}" }
                sort keys %{$env{$type}};
    }

    return +{
        machine => +{
            hostname => hostname,
            envhard => $env{envhard} || '',
            envsoft => $env{envsoft} || '',
        },
        resources => \@res,
    }
}

1;
