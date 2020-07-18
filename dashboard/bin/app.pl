#!/opt/mydan/perl/bin/perl -I/opt/AntDen/lib
$|++;
use AntDen;
use MYDan;
use Dancer;
use dashboard;
use dashboard::admin;
use dashboard::user;
use dashboard::userinfo;
use dashboard::mydan;
use api::antdencli;
use api::agent;
$0 = 'AntDen_dashboard_service';
dance;
