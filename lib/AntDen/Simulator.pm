package AntDen::Simulator;
use strict;
use warnings;
use Carp;
use YAML::XS;
use POSIX;

use AntDen::Simulator::Generator;

sub new
{
    my ( $class, %this ) = @_;

    $SIG{INT} = $SIG{TERM} = sub{
        system "kill 0";
        die "kill.\n";
    };

    map{ die "$_ undef" unless $this{$_} }qw( scheduler conf name );
    die "name undef" unless my $name = $this{name};
    die "path undef" unless my $path = $this{scheduler};
    $this{uuid} = sprintf "%s.%04d", POSIX::strftime( "%Y%m%d_%H%M%S", localtime ), int rand 10000;

    map{ die "touch $this{uuid}.$_ fail: $!" if system "touch $path/run/$this{uuid}.$_"; }qw( in out );

    die "start plugin fail: $!"
        if system "tail -n 999999999 -f $path/run/$this{uuid}.in | $path/$name > $path/run/$this{uuid}.out &";

    die "open $path/run/$this{uuid}.in fail: $!" unless open $this{in}, ">", "$path/run/$this{uuid}.in";
    die "open $path/run/$this{uuid}.out fail: $!" unless open $this{out}, "<", "$path/run/$this{uuid}.out";

    bless \%this, ref $class || $class;
}

sub run
{
    my $this = shift;

    my $generator = AntDen::Simulator::Generator->new( conf => $this->{conf} );
    my $H = $this->{out};
    while(1)
    {
        my @feedback;
        while( 1 )
        {
            my $feedback = <$H>;
            last unless $feedback;
            push @feedback, $feedback;
        }
        map{ syswrite $this->{in}, "$_\n"; } $generator->generator( @feedback );
    }
}

1;
