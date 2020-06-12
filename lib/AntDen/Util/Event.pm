package AntDen::Util::Event;
use strict;
use Carp;
use POSIX;
use YAML::XS;
use Time::HiRes 'gettimeofday';
use Linux::Inotify2;
use File::Basename;
use Time::HiRes qw( sleep );

sub new
{
    my ( $class, %this ) = @_;

    die "error: path undefind" unless $this{path};
    system "mkdir -p '$this{path}'" unless -d $this{path};
    die "error: $this{path} nofind" unless -d $this{path};

    bless \%this, ref $class || $class;
}

sub receive
{
    my ( $this, $THIS, $consume, %ext ) = @_;

    my $CONSUME = sub
    {
        my ( $this, $file ) = @_;
        my $name = basename $file;
        if( $name =~ /E\.\d{8}.\d{6}.\d{6}.\d{9}$/ )
        {
ABC:
            return unless -f $file;
            my $conf = eval{ YAML::XS::LoadFile $file };
            warn "load conf $file fail: $@" if $@;
            unless( $conf && ref $conf eq 'HASH' )
            {
                warn "error $file no hash\n";
                sleep 0.2;
                goto ABC; 
            }
            &$consume( $this, +{ %$conf, %ext } );
        }
        unlink $file;
    };

    my $inotify = new Linux::Inotify2 or die "unable to create new inotify object: $!";
    $inotify->watch( $this->{path}, IN_CREATE | IN_MOVED_TO, sub {
       &$CONSUME( $THIS, shift->fullname );
    });
    my $inotify_w = AE::io $inotify->fileno, 0, sub { $inotify->poll; };

    #TODO
    map{ &$CONSUME( $THIS, $_ ); }glob "$this->{path}/*";

    return $inotify_w;
}

sub send
{
    my ( $this, $conf ) = @_;
    my ( $sec ,$usec ) = gettimeofday;
    my $eid = sprintf "E.%s.%06d.%09d", POSIX::strftime( "%Y%m%d.%H%M%S", localtime( $sec ) ), $usec, rand( 1000000000 );

    eval{ YAML::XS::DumpFile "$this->{path}/$eid", $conf };
    die "send event fail $@" if $@;
}

sub len
{
    my $this = shift;
    return scalar( my @x = glob "$this->{path}/*" );
}

1;
