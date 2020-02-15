package AntDen::Util::Control;
use strict;
use warnings;
use Carp;
use AntDen;
use MYDan;

sub new
{
    my ( $class, $name ) = @_;
    bless +{ name => $name }, ref $class || $class;
}

sub start
{
    my $this = shift @_;
    my $name = $this->{name};

    if( my @x = `ps -ef|grep [A]ntDen_${name}_`  )
    {
        print @x;
        die "error: $name already running!\n";
    }

    die "start $_ fail: $!" if system "$MYDan::PATH/dan/tools/supervisor --name AntDen_${name}_supervisor --cmd '$AntDen::PATH/$name/service/$name.service' --log '$AntDen::PATH/logs/$name'";
    sleep 1;
    $this->status();
}

sub stop
{
    my $this = shift @_;
    my $name = $this->{name};
    system "killall AntDen_${name}_supervisor";
    system "killall AntDen_${name}_service";
}
sub restart
{
    my $this = shift @_;
    my $name = $this->{name};

    $this->stop();
    while(1)
    {
        sleep 1;
        last unless my @x = `ps -ef|grep [A]ntDen_${name}_`;
    }
    $this->start();

}
sub status
{
    my $this = shift @_;
    print "Process:\n";
    system "ps -ef|grep [A]ntDen_$this->{name}_";
}

sub tail
{
    my $this = shift @_;
    exec "tail -n 30 -F $AntDen::PATH/logs/$this->{name}/current";
}

1;
__END__
