package AntDen::Simulator::Generator::Job;
use strict;
use warnings;

use Fcntl 'O_RDONLY';
use Tie::File;

our %TASK;
our %STAT = ( init => 0, running => 0, stoped => 0 );

use AntDen::Simulator::Generator::Machine;

sub new
{
    my ( $class, %this ) = @_;

    die "tie conf fail: $!" unless tie my @conf, 'Tie::File', "$this{conf}/job", mode => O_RDONLY;
    my @x = @conf;
    $this{config} = \@x;
    delete $this{tempconfig};
    $this{id} = 0;
    bless \%this, ref $class || $class;
}

sub generator
{
    my ( $this, @stoped ) = shift;

    for my $id ( keys %TASK )
    {
        $TASK{$id}{time} ++ if $TASK{$id}{sche};
        if( $TASK{$id}{time} && $TASK{$id}{time} > $TASK{$id}{sche}{executer}{param}{runtime} )
        {
            my $c = delete $TASK{$id};
# $c =>
#          'sche' => {
#                      'resources' => [
#                                       [
#                                         'CPU',
#                                         '0',
#                                         '2'
#                                       ]
#                                     ],
#                      'executer' => {
#                                      'name' => 'exec',
#                                      'param' => {
#                                                   'exec' => 'sleep 300'
#                                                   'runtime' => 6
#                                                 }
#                                    },
#                      'ingress' => undef,
#                      'group' => 'foo',
#                      'jobid' => 'J.35',
#                      'taskid' => 'T.35.003',
#                      'hostip' => '10.0.2.47'
#                    },
#          'conf' => '',
#          'time' => 2007,
#          'id' => 'T.35.003'

            my $jobid = $id;
            $jobid =~ s/^T/J/;
            $jobid =~ s/\.\d+$//;
            $STAT{stoped} ++;
            my $resources = $c->{sche}{resources};
            for my $type ( qw( CPU MEM GPU PORT ) )
            {
                map{
                    $AntDen::Simulator::Generator::Machine::STAT{$_->[0]} += $_->[2] if $_->[0] eq $type;
                }@$resources;
            }

            push @stoped, +{
                name => 'stoped',
                data => [
                    +{
                        taskid => $id,
                        jobid => $jobid,
                        status => 'success',
                        result => 'exit:0',
                        msg => 'mesg1',
                        usetime => 6,
                     }
                ]

            }
        }
    }

    my $config = $this->{config};
    return( @stoped ) unless $this->{tempconfig} || @$config;

    unless( $this->{tempconfig} )
    {
        my $conf = shift @$config;
 
        my ( @res, %x );

        map{
            my @x = split /:/, $_;
            if( grep{ $x[0] eq $_ }qw( CPU MEM PORT GPU ) )
            {
                push( @res, [ $x[0], '.', $x[1] ] ) if @x == 2;
                push( @res, \@x ) if @x == 3;
            }
            else
            {
                $x{$x[0]} = $x[1];
            }
        }split /\s+/, $conf;

        $x{repeat} ||= 1;
        $x{count} ||= 1;
        $x{nice} ||= 5;
        $x{runtime} ||= 1;
        $this->{tempconfig} = +{ conf => \%x, res => \@res };
    }

    $this->{id} ++;

    my @data = (
        +{
            nice => $this->{tempconfig}{conf}{nice},
            jobid => "J.$this->{id}",
            group => $this->{tempconfig}{conf}{group},
            conf => [
                +{
                    executer => +{
                        param => +{ exec => 'sleep 300', runtime => $this->{tempconfig}{conf}{runtime} },
                        name => 'exec'
                    },
                    scheduler => +{
                        envhard => "arch=x86_64,os=Linux",
                        count => $this->{tempconfig}{conf}{count},
                        envsoft => "app1=1.0",
                        resources => $this->{tempconfig}{res}
                    }
                }
            ]
         }
    );

    map{
        my $id = sprintf( "T.$this->{id}.%03d", $_ );
        $TASK{$id} = +{ id => $id, conf => '' }; 
        $STAT{init} ++;
    }1..$this->{tempconfig}{conf}{count};

    $this->{tempconfig}{conf}{repeat} --;
    delete $this->{tempconfig} unless $this->{tempconfig}{conf}{repeat};

    return +{ name => 'submitJob', data => \@data }, @stoped;
}

1;
