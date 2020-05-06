package AntDen::Simulator::Generator::Machine;
use strict;
use warnings;

use Fcntl 'O_RDONLY';
use Tie::File;

our %STAT = ( machine => 0, CPU => 0, MEM => 0, GPU => 0, PORT => 0 );

sub new
{
    my ( $class, %this ) = @_;
    my $conf = "$this{conf}/machine";
    die "tie conf fail: $!" unless tie my @conf, 'Tie::File', "$this{conf}/machine", mode => O_RDONLY;
    my @x = @conf;
    $this{config} = \@x;
    $this{id} = 0;
    bless \%this, ref $class || $class;
}

sub generator
{
    my ( $this, @machine ) = @_;

    my $config = $this->{config};
    return unless @$config;
    my $conf = shift @$config;
    my $count = 1;
    my @res;
    my %conf; map{
        my @x = split /:/, $_;
        if ( $x[0] eq 'count' )
        {
            $count = $x[1];
        }
        else
        {
            push( @res, [ $x[0], 0, $x[1] ] )if @x == 2;
            push( @res, [ $x[0], $x[1], $x[2] ] ) if @x == 3;
        }
    }split /\s+/, $conf;

    $this->{id} ++;
    my $id = 0;
    for( 1 .. $count )
    {
        $id ++;
        my $ip = "10.0.$this->{id}.$id";
        my @setMachine = (
            $ip,
            +{
                mon => "MEM=1159,health=1,load=0.26",
                group => "foo",
                hostname => "node.$this->{id}.$id",
                switchable => 1,
                envhard => "arch=x86_64,os=Linux",
                envsoft => "SELinux=Disabled",
                role => "slave",
                workable => 1,
             }
        );

        $STAT{machine} ++;

        my @setResource = (
            $ip,
            \@res,
        );
        map{ $STAT{$_->[0]} += $_->[2] }@res;
        push @machine, +{ name => 'setMachine', data => \@setMachine },
            +{ name => 'setResource', data => \@setResource };

    }
    return @machine;
}

1;
