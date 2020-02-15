package AntDen::Slave::Executer::Code;
use strict;
use warnings;

sub new
{
    my ( $class, %this ) = @_;

    die "path undef" unless $this{path} && -d $this{path};

    bless \%this, ref $class || $class;
}

sub do
{
    my ( $this, $name, $ctrl, $conf ) = @_;

    die "get _executer fail: $name, $ctrl"
        unless my $code = $this->_executer( $name, $ctrl );

    return &$code( $conf );
}

sub _executer
{
    my ( $this, $name, $ctrl ) = @_;

    my $path = "$this->{path}/$name/$ctrl";
    unless( $this->{executer}{$name}{$ctrl} )
    {
        $this->{executer}{$name}{$ctrl}
            = sub{ return 'noresult';} if $ctrl eq 'result' && ! -f $path;

        my $code = do $path;
        $this->{executer}{$name}{$ctrl} = $code if $code && ref $code eq 'CODE';
    }

    return $this->{executer}{$name}{$ctrl};
}

1;
