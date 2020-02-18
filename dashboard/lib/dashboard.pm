package dashboard;
use Dancer ':syntax';

use POSIX;
use FindBin qw( $RealBin );

our $VERSION = '0.1';
our ( $schedulerCtrl, $schedulerDB, %addr, %opt );

BEGIN{
    use MYDan::Util::OptConf;
    use AntDen::Scheduler::Ctrl;
    use AntDen::Scheduler::DB;
    $MYDan::Util::OptConf::THIS = 'antden';
    my $option = MYDan::Util::OptConf->load();
    %opt = $option->get()->dump();
    $schedulerCtrl = AntDen::Scheduler::Ctrl->new( %{$opt{scheduler}} );
    $schedulerDB = AntDen::Scheduler::DB->new( $opt{scheduler}{db} );
    my @addr = `cat $RealBin/../whitelist`;
    chomp @addr;
    %addr = map{ $_ => 1 }@addr;
};

get '/' => sub {
    my @machine = $schedulerDB->selectMachineInfo();
    #`ip`,`hostname`,`envhard`,`envsoft`,`switchable`,`group`,`workable`,`role`

    my @resources = $schedulerDB->selectResourcesInfo();
    #`ip`,`name`,`id`,`value`
    my ( %r, %t );
    for ( @resources )
    {
        my ( $ip, $name, $id, $value ) = @$_;
        $r{$ip}{$name} += $value;
        $t{$name} += $value;
    }
    my @total = map{ [ $_, $t{$_} ] }sort keys %t;
    for my $ip ( keys %r )
    {
        $r{$ip} = join ',', map{ "$_=$r{$ip}{$_}" } sort keys %{$r{$ip}};
    }
    map{ push @$_, $r{$_->[0]} }@machine;
    template 'index', +{ machine => \@machine, total => \@total };
};

get '/slave/resources' => sub {
    my @machine = $schedulerDB->selectMachineInfo();
    #`ip`,`hostname`,`envhard`,`envsoft`,`switchable`,`group`,`workable`,`role`
    template 'slave/resources', +{ machine => \@machine };
};

get '/scheduler/submitJob' => sub {
    my $param = params();
    my ( $configStr, $niceStr, $groupStr, $err, $jobid )
        = ( $param->{config}, $param->{nice}, $param->{group}, '', '' );

    if( $configStr )
    {
        unless( defined $niceStr && $niceStr =~ /^\d+$/ )
        {
            $err = 'nice error';
        }elsif( !( defined $groupStr && $groupStr =~ /^[a-zA-Z0-9]+$/ ))
        {
            $err = 'group error';
        }
        else
        {
            my $config = eval{ YAML::XS::Load $param->{config} };
            if( $@ )
            {
                $err = "config format error: $@";
            }
            elsif( ! ( $config && ref $config eq 'ARRAY' ) )
            {
                $err = 'config format error: no ARRAY';
            }
            else
            {
                 $jobid = $schedulerCtrl->startJob( $config, $niceStr, $groupStr );
                 $configStr = '';
            }
        }
    }
    $niceStr = 5 if ! defined $niceStr;
    template 'scheduler/submitJob', +{ config => $configStr, nice => $niceStr,
        group => $groupStr, err => $err, jobid => $jobid };
};

hook 'before' => sub {
    my $addr = request->env->{REMOTE_ADDR};
    halt( 'Unauthorized:' . $addr ) unless $addr{$addr};
};

get '/scheduler/job' => sub {
    my @job = $schedulerDB->selectJobWorkInfo();
    #`id`,`jobid`,`nice`,`group`,`status`,`ingress`
    template 'scheduler/jobs', +{ jobs => \@job };
};

get '/scheduler/task/:taskid' => sub {
    my $param = params();
    my $taskid = $param->{taskid};
    my $config = eval{ YAML::XS::Dump YAML::XS::LoadFile "$opt{scheduler}{conf}/task/$taskid" };

    template 'scheduler/task', +{ config => $config };
};

get '/scheduler/job/:jobid' => sub {
    my $param = params();
    my $jobid = $param->{jobid};
    my @task = $schedulerDB->selectTaskByJobid( $jobid );
    #id,jobid,taskid,hostip,status,result,msg,usetime,domain,location,port
    my @job = $schedulerDB->selectJobByJobid( $jobid );
    #id,jobid,nice,group,status
    my $config = eval{ YAML::XS::Dump YAML::XS::LoadFile "$opt{scheduler}{conf}/job/$jobid" };

    template 'scheduler/job', +{ config => $config, task => \@task, job => $job[0] };
};

get '/scheduler/job/renice/:renice/:jobid' => sub {
    my $param = params();
    my ( $jobid, $renice ) = @$param{ qw( jobid renice ) };

    return "jobid format error" unless $jobid && $jobid =~ /^J[0-9\.]+$/;
    return "renice format error" unless defined $renice && $renice =~ /^\d+$/;

    $schedulerCtrl->reniceJob( $jobid, $renice );
    return "renice job: $jobid success";
};

get '/scheduler/job/stop/:jobid' => sub {
    my $param = params();
    my $jobid = $param->{jobid};
    return "jobid format error" unless $jobid && $jobid =~ /^J[0-9\.]+$/;
    $schedulerCtrl->stopJob( $jobid );
    return "stop job: $jobid success";
};

get '/scheduler/jobHistory' => sub {
    my @job = $schedulerDB->selectJobStopedInfo();
    #`id`,`jobid`,`nice`,`group`,`status`
    template 'scheduler/jobHistory', +{ jobs => \@job };#+{ jobs => \@jobs };
};

get '/tasklog/:uuid' => sub {
    my $uuid = params()->{uuid};
    my $ws_url = request->env->{HTTP_HOST};
    $ws_url =~ s/:\d+$//;
    $ws_url .= ":3001";
    $ws_url = "ws://$ws_url/ws";
    template 'scheduler/tasklog', +{ ws_url => $ws_url, uuid => $uuid };
};

true;
