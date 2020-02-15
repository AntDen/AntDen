package AntDen::Slave;
use strict;
use warnings;

our ( %status2id, %id2status );
BEGIN{
    my @status = qw( init starting running stopping exiting stoped );
    map{
        $status2id{$status[$_]} = $_ + 1;
        $id2status{$_ + 1} = $status[$_];
    }0 .. $#status;
}

1;
