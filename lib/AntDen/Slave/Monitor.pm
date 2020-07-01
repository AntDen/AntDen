package AntDen::Slave::Monitor;
use strict;
use warnings;

use Carp;
use YAML::XS;
use File::Basename;
use Sys::Hostname;

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

    $this{hostname} = hostname;

    bless \%this, ref $class || $class;
}

sub do
{
    my ( $this, %data ) = shift @_;
    for my $name ( keys %{$this->{code}} )
    {
        my $r = &{$this->{code}{$name}};
        next unless defined $r;

        if( $name ne 'TASK' && ref $r eq 'HASH' )
        {
            map{ $data{"$name.$_"} = $r->{$_}; }keys %$r;
        }
        else { $data{$name} = $r; }
    }
    $data{time} = time;
    $data{hostname} = $this->{hostname};
    return \%data;
}

1;
