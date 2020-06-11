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
        map{ die "nofind $_" unless $conf->{$_} } qw( resources executer );
        $this->_send( +{ %$conf, ctrl => 'start' } );
    }
}

=head3 stop( $conf )

  taskid: T.0
  jobid: J.0
  hostip: 127.0.0.1

=cut

sub stop
{
    my $this = shift @_;
    map{ $this->_send( +{ %$_, ctrl => 'stop' } ); }@_;
}

sub _send
{
    my ( $this, $conf ) = @_;

    map{ die "$_ undef" unless $conf->{$_} }qw( jobid taskid hostip );
    $conf->{jobid} ||= 'J.0';

    my $path = "$this->{conf}/slave/$conf->{hostip}/in";
    system "mkdir -p '$path'" unless -d $path;
    AntDen::Util::Event->new( path => $path )->send( $conf );
}

sub dumpMachine
{
    my $this = shift @_;
    eval { YAML::XS::DumpFile "$this->{conf}/slave.ip", \@_ };
    die "save slave.ip fail $@" if $@;
}

1;
