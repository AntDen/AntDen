package AntDen::Util::Command;
use strict;
use warnings;
use Carp;
use AntDen;

sub new
{
    my ( $class, $name, $cmd, $alias ) = @_;
    bless +{ name => $name, cmd => $cmd, alias => $alias || +{} }, ref $class || $class;
}

sub do
{
    my ( $this, $cmd, @argv )= @_;

    $ENV{AntDen_DEBUG} = 1 && $cmd = lc( $cmd ) if $cmd && $cmd =~ /^[A-Z][a-z]*$/;

    $cmd = $this->{alias}{$cmd} if $cmd && $this->{alias}{$cmd};

    my ( $c ) = grep{ $cmd && $_->[0] eq $cmd }@{$this->{cmd}};

    $this->help() and return unless $c;

    my @x = splice @$c, 2;
    map{ exec join( ' ', "$AntDen::PATH/$_", map{"'$_'"}@argv ) if -e "$AntDen::PATH/$_" }@x;
    print "$cmd is not installed\n";
}

sub help
{
    my $this = shift;

    my ( $name, $cmd ) = @$this{qw( name cmd )};

    print "Usage: $name COMMAND [arg...]\n";
    print "\tHelp\tshow detail\n";
    print "Commands:\n";

    my %alias;map{ $alias{$this->{alias}{$_}} = $_ }keys %{$this->{alias}};
    map{
        printf "\t$_->[0]%s\t$_->[1]\n", $alias{$_->[0]} ? "( alias: $alias{$_->[0]})": '';
    }@$cmd;

    print "\nRun '$name COMMAND --help' for more information on a command.\n"
}

1;
__END__
