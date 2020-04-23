package AntDen::Scheduler::Mon;
use strict;
use warnings;

sub new
{
    my ( $class, %this ) = @_;

    die "error a undefind" unless $this{a};
    $this{data} = +{};

    bless \%this, ref $class || $class;
}

=head3 add( $conf )

  hostip: 127.0.0.1
  health: 1
  MEM: 10
  load: 1.0

=cut

sub add
{
    my ( $this, $conf ) = @_;
    $this->{data}{$conf->{hostip}} = $conf;
}

sub save
{
    my ( $this, @ip ) = @_;

    for my $ip ( @ip )
    {
        $this->{data}{$ip} ||= +{ health => 0 };

        $this->{a}->setMachineAttr(
            $ip, 'mon',
            join ',', map{ "$_=$this->{data}{$ip}{$_}" }
                grep{ $_ ne 'hostip' && $_ ne 'ctrl' } sort keys %{$this->{data}{$ip}} );
    }
    $this->{data} = +{};
}
1;
