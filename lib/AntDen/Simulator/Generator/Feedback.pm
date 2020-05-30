package AntDen::Simulator::Generator::Feedback;
use strict;
use warnings;

use AntDen::Simulator::Generator::Job;
use AntDen::Simulator::Generator::Machine;

sub new
{
    my ( $class, %this ) = @_;
    bless \%this, ref $class || $class;
}

sub generator
{
    my ( $this, @feedback ) = @_;
    @feedback = grep{ ref $_ eq 'ARRAY' }@feedback;
    map{
        # $_ =>
        #      'executer' => {
        #                      'name' => 'exec',
        #                      'param' => {
        #                                   'exec' => 'sleep 300'
        #                                 }
        #                    },
        #      'taskid' => 'T.34.002',
        #      'resources' => [
        #                       [
        #                         'CPU',
        #                         '0',
        #                         '2'
        #                       ]
        #                     ],
        #      'ingress' => undef,
        #      'jobid' => 'J.34',
        #      'group' => 'foo',
        #      'hostip' => '10.0.2.39'
        if( $_->{executer}{name} eq 'buy' )
        {
            push @{AntDen::Simulator::Generator::Product::BUY}, $_->{executer}{param}{productid};
        }
        if( $AntDen::Simulator::Generator::Job::TASK{$_->{taskid}} )
        {
            $AntDen::Simulator::Generator::Job::TASK{$_->{taskid}}{sche} = $_;
            $AntDen::Simulator::Generator::Job::STAT{running} ++;

            my $resources = $_->{resources};
            for my $type ( qw( CPU GPU MEM PORT ) )
            {
                map{
                    $AntDen::Simulator::Generator::Machine::STAT{$_->[0]} -= $_->[2] if $_->[0] eq $type;
                }@$resources;
            }
        }

    }map{ @$_ }@feedback;

    return ();
}

1;
