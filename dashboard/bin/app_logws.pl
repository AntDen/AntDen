#!/opt/mydan/perl/bin/perl -I/opt/AntDen/lib
use strict;
use warnings;
 
use FindBin;
use lib "$FindBin::Bin/../lib";
 
use Plack::Builder;
 
use logws;
 
builder {
    mount( logws->websocket_mount );
    mount '/' => logws->to_app;
}
