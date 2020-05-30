package AntDen::Simulator::Generator;
use strict;
use warnings;
use JSON;

use AntDen::Simulator::Generator::Machine;
use AntDen::Simulator::Generator::Job;
use AntDen::Simulator::Generator::Time;
use AntDen::Simulator::Generator::Feedback;
use AntDen::Simulator::Generator::Product;

sub new
{
    my ( $class, %this ) = @_;

    $this{machine} = AntDen::Simulator::Generator::Machine->new( conf => $this{conf} );
    $this{job} = AntDen::Simulator::Generator::Job->new( conf => $this{conf} );
    $this{time} = AntDen::Simulator::Generator::Time->new();
    $this{feedback} = AntDen::Simulator::Generator::Feedback->new();
    $this{product} = AntDen::Simulator::Generator::Product->new( conf => $this{conf} );

    my %x = %AntDen::Simulator::Generator::Job::STAT;
    my %o = %AntDen::Simulator::Generator::Machine::STAT;

    my @sort = sort keys %o;
    printf "time\tinit\trunning\tstoped\t%s\n", join "\t", @sort;

    bless \%this, ref $class || $class;
}

sub generator
{
    my ( $this, @feedback, @data ) = @_;

    my @x = eval{ map{ JSON::from_json( $_ )}@feedback };
    die "load data from feedback fail: $@" if $@;

    my $xt = 0;
    map{ $xt = $_->{data}[0] if ref $_ eq 'HASH' && $_->{name} eq 'time' && $_->{data}[0] > $xt; }@x;
    if( $xt == $this->{time}->time() )
    {
        push @data, $this->{time}->generator();
        push @data, $this->{machine}->generator();
        push @data, $this->{job}->generator();
        push @data, $this->{product}->generator( $this->{time}->time() );

        my %x = %AntDen::Simulator::Generator::Job::STAT;
        my %o = %AntDen::Simulator::Generator::Machine::STAT;
        my @sort = sort keys %o;
        printf "%s\t$x{init}\t$x{running}\t$x{stoped}\t%s\n",
            $this->{time}->time(), join "\t", map{ $o{$_} }@sort;
    }

    push @data, $this->{feedback}->generator( @x );

    return map{ JSON::to_json( $_ ) }@data;
}

1;
