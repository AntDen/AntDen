package AntDen::Simulator::Generator::Time;
use strict;
use warnings;

use AntDen::Simulator::Generator::Job;

sub new
{
    my ( $class, %this ) = @_;
    $this{time} = 0;
    $this{temp} = [ map{ $_ - 100 } 1.. 40 ];
    bless \%this, ref $class || $class;
}

sub generator
{
    my $this = shift;

    my %x = %AntDen::Simulator::Generator::Job::STAT;
    $this->{time} ++;
    my $i = $this->{time} % 20;

    $this->{temp}[$i] = $x{init};
    $this->{temp}[$i+20] = $x{stoped};

    exit if $x{init} eq $x{stoped} && 39 eq grep{ $this->{temp}[0] eq $this->{temp}[$_] } 1 .. 39;

    return +{ name => 'time' , data => [ $this->{time} ] }, +{ name => 'apply' , data => [] };
}

sub time
{
    return shift->{'time'};
}

1;
