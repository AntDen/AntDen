package AntDen::Util::UUID;
use strict;
use warnings;

use POSIX;
use Time::HiRes 'gettimeofday';

sub new
{
    my $class = shift @_;
    bless +{}, ref $class || $class;
}

sub jobid
{
    return shift->_uuid( 'J' );
}

sub taskid
{
    return shift->_uuid( 'T' );
}

sub sysTaskid
{
    return shift->_uuid( 't' );
}

sub _uuid
{
    my ( $this, $H ) = @_;
    my ($sec ,$usec ) = gettimeofday;
    return sprintf "%s.%06d.%03d", 
        POSIX::strftime( "$H.%Y%m%d.%H%M%S", localtime( $sec ) ), $usec, rand( 1000 );
}

1;
