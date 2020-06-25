package AntDen::Slave::Monitor;
use strict;
use warnings;

use Carp;
use POSIX;
use YAML::XS;
use File::Basename;

sub new
{
    my ( $class, %this ) = @_;

    die "path undef" unless $this{path} && -d $this{path};

    for my $file ( glob "$this{path}/*" )
    {
        my $code = do $file;
        die "load code $file fail: $!" unless $code && ref $code eq 'CODE';
        $this{code}{basename $file} = $code;
    }

    bless \%this, ref $class || $class;
}

sub do
{
    my ( $this, %data ) = shift @_;
    map{ $data{$_} = &{$this->{code}{$_}}; }keys %{$this->{code}};
    $data{time} = POSIX::strftime( "%Y-%m-%d %H:%M:%S", localtime );
    return \%data;
}

1;
