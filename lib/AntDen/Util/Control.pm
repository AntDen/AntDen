package AntDen::Util::Control;
use strict;
use warnings;
use Carp;
use AntDen;
use MYDan;

sub new
{
    my ( $class, $name, $docker ) = @_;
    bless +{ name => $name, docker => $docker ? 'docker' : '' }, ref $class || $class;
}

sub start
{
    my $this = shift @_;
    my ( $name, $docker ) = @$this{ qw( name docker ) };

    if( my @x = `ps -ef|grep [A]ntDen_${docker}${name}_s`  )
    {
        print @x;
        die "error: $docker$name already running!\n";
    }

    die "start $_ fail: $!" if system "$MYDan::PATH/dan/tools/supervisor --name AntDen_${docker}${name}_supervisor --cmd '$AntDen::PATH/$name/service/$name.service' --log '$AntDen::PATH/logs/$name'";
    sleep 1;
    $this->status();
}

sub stop
{
    my $this = shift @_;
    my ( $name, $docker ) = @$this{ qw( name docker ) };
    system "killall AntDen_${docker}${name}_supervisor";
    system "killall AntDen_${docker}${name}_service";
}
sub restart
{
    my $this = shift @_;
    my ( $name, $docker ) = @$this{ qw( name docker ) };

    $this->stop();
    while(1)
    {
        sleep 1;
        last unless my @x = `ps -ef|grep [A]ntDen_${docker}${name}_s`;
    }
    $this->start();

}
sub status
{
    my $this = shift @_;
    print "Process:\n";
    system "ps -ef|grep [A]ntDen_$this->{docker}$this->{name}_";
}

sub tail
{
    my $this = shift @_;
    exec "tail -n 30 -F $AntDen::PATH/logs/$this->{name}/current";
}

1;
__END__
