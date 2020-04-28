package AntDen::Scheduler::Temple::Pandora;
use strict;
use warnings;

use JSON;
use POSIX;

sub new
{
    my ( $class, %this ) = @_;
    die "env Pandora undef" unless my $name = $ENV{AntDenSchedulerTemple} || 'pandora:clotho';
    $name =~ s/^pandora://;
    die "name error" unless $name && $name ne 'pandora';

    die "path undef" unless my $path = $this{path};
    $this{uuid} = POSIX::strftime( "%Y%m%d_%H%M%S", localtime );

    map{ die "touch $this{uuid}.$_ fail: $!" if system "touch $path/run/$this{uuid}.$_"; }qw( in out );

    die "start plugin fail: $!"
        if system "tail -n 999999999 -f $path/run/$this{uuid}.in | $path/$name > $path/run/$this{uuid}.out &";

    die "open $path/run/$this{uuid}.in fail: $!" unless open $this{in}, ">", "$path/run/$this{uuid}.in";
    die "open $path/run/$this{uuid}.out fail: $!" unless open $this{out}, "<", "$path/run/$this{uuid}.out";

    bless \%this, ref $class || $class;
}

sub AUTOLOAD
{
    my $this = shift;
    return unless our $AUTOLOAD =~ /::(\w+)$/;
    my $name = $1;
    my $data = +{ name => $name, data => \@_ };
    my $d = JSON::to_json( $data );
    syswrite $this->{in}, $d."\n";

    return unless $name eq 'apply';
    my $H = $this->{out};
    my $x = <$H>;
    return () unless $x;
    my $dd = eval{ JSON::from_json $x };
    die "from_json fail: $@" if $@;
    return @{$dd};
}

1;
