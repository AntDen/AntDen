#!/opt/mydan/perl/bin/perl
use strict;
use warnings;
use Digest::MD5;

die "env MYDan_api error:$ENV{MYDan_api}" unless $ENV{MYDan_api} && $ENV{MYDan_api} =~ /^[\.:a-zA-Z0-9_\/\-]+$/; 
die "env MYDan_username error:$ENV{MYDan_username}" unless $ENV{MYDan_username} && $ENV{MYDan_username} =~ /^[\.:a-zA-Z0-9_\@\-]+$/;
die "env MYDan_keymd5 error:$ENV{MYDan_keymd5}" unless $ENV{MYDan_keymd5} && $ENV{MYDan_keymd5} =~ /^[a-zA-Z0-9]+$/; 

my $user = `id -un`;
chop $user;
my $home = $ENV{HOME} || ( getpwnam $user )[7];

mkdir "$home/.ssh" unless -d "$home/.ssh";
my $path = "$home/.ssh/antden.key";

my $localmd5;
if( -f $path )
{
    open my $H, '<', $path or die "Can't open '$path': $!";
    $localmd5 = Digest::MD5->new()->addfile( $H )->hexdigest();
    close $H;
}

unless( $localmd5 && $localmd5 eq $ENV{MYDan_keymd5} )
{
    my $url = "$ENV{MYDan_api}/user/settings/key?user=$ENV{MYDan_username}&md5=$ENV{MYDan_keymd5}";
    die "wget $url fail: $!" if system "wget '$url' -O $path"
}

die "change mydan api fail: $!" if system "mydan config api.addr=$ENV{MYDan_api}";
exec "/opt/mydan/dan/antden/bin/antdencli @ARGV"
