#!/opt/mydan/perl/bin/perl -I/opt/AntDen/lib
use Dancer;
use dashboard;
use dashboard::admin;
use api::antdencli;
$0 = 'AntDen_dashboard_service';
dance;
