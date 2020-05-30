package AntDen::Simulator::Generator::Product;
use strict;
use warnings;

use Fcntl 'O_RDONLY';
use Tie::File;

use AntDen::Simulator::Generator::Machine;
our @BUY;

sub new
{
    my ( $class, %this ) = @_;

    die "tie conf fail: $!" unless tie my @conf, 'Tie::File', "$this{conf}/product", mode => O_RDONLY;
    my @x = @conf;
    $this{config} = \@x;
    $this{productinfo} = +{};
    $this{buy} = [];

    bless \%this, ref $class || $class;
}

sub generator
{
    my ( $this, $time ) = @_;

    if( @BUY )
    {
        while( 1 )
        {
            last unless my $productid = shift @BUY;
            push @{$this->{buy}}, +{ %{$this->{productinfo}{$productid}}, createedtime => $time + $this->{productinfo}{$productid}{conf}{startingtime} };
        }

        return ();
    }

    if( @{$this->{buy}} )
    {
        map{ push( @{AntDen::Simulator::Generator::Machine::ADD}, $_ ) if $_->{createedtime} >= $time  }@{ $this->{buy} };
        $this->{buy} = [ grep{ $_->{createedtime} < $time }@{ $this->{buy} } ];
        return ();
    }
    my $config = $this->{config};
    my @product;
    if( @$config )
    {
        my $conf = shift @$config;
        my ( @res, %x );

        map{
            my @x = split /:/, $_;
            if( grep{ $x[0] eq $_ }qw( CPU MEM PORT GPU ) )
            {
                push( @res, [ $x[0], '.', $x[1] ] ) if @x == 2;
                push( @res, \@x ) if @x == 3;
            }
            else
            {
                $x{$x[0]} = $x[1];
            }
        }split /\s+/, $conf;
        $this->{productinfo}{$x{id}} =  +{ conf => \%x, res => \@res };

        return +{ name => 'addProduct', data => [ +{ conf => \%x, res => \@res } ] };
    }

    return ();
}

1;
