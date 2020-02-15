package AntDen::Util::Environment;
use strict;
use warnings;

sub new
{
    my ( $class, %this ) = @_;

    $this{match} = +{};

    bless \%this, ref $class || $class;
}

sub match
{
    my ( $this, $a, $b ) = @_;
    unless( defined $this->{match}{$a}{$b} )
    {
        my %a;
        for( split /,/, $a )
        {
            my @x = split /=/, $_, 2;
            next unless @x && @x == 2;
            $a{$x[0]} = $x[1];
        }

        my $match = keys %a ? 1 : 0;
        for( split /,/, $b )
        {
            my @x = split /=/, $_, 2;
            next unless @x && @x == 2;
            unless( $a{$x[0]}  && $a{$x[0]} eq $x[1] )
            {
                $match = 0;
                last;
            }
        }
        $this->{match}{$a}{$b} = $match;
    }
    return $this->{match}{$a}{$b};
}

1;
