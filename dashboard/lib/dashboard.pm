package dashboard;
use Dancer ':syntax';

use POSIX;
use FindBin qw( $RealBin );
use JSON;

set serializer => 'JSON';
set show_errors => 1;

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
    #`ip`,`hostname`,`envhard`,`envsoft`,`switchable`,`group`,`workable`,`role`,`mon`

    my @resources = $schedulerDB->selectResourcesInfo();
    #`ip`,`name`,`id`,`value`
    my ( %r, %t, %used, %use );
    for ( @resources )
    {
        my ( $ip, $name, $id, $value ) = @$_;
        $r{$ip}{$name} += $value;
        $t{$name} += $value;
    }

    for ( @machine )
    {
        my ( $ip, $mon ) = @$_[0,8];
        map{
            my @x = split /=/, $_, 2;
            $used{$ip}{$x[0]} = $x[1] || 0;
        }split ',', $mon;
    }    

    for my $ip ( keys %r )
    {
        map{ $used{$ip}{$_} = $r{$ip}{$_} unless defined $used{$ip}{$_} }keys %{$r{$ip}};
        $r{$ip} = join ',', map{ "$_=$r{$ip}{$_}" } sort keys %{$r{$ip}};
    }
    map{ push @$_, $r{$_->[0]} }@machine;

    for my $v ( values %used )
    {
        map{ $use{$_} += $v->{$_} }keys %$v;
    }

    $t{health} = scalar @machine;
    $t{load} = int( $t{CPU} / 1024 ) if $t{CPU};

    my @total = map{ [ $_, $use{$_}, $t{$_} ] }sort keys %t;
    
    template 'index', +{ machine => \@machine, total => \@total };
};

get '/slave/resources' => sub {
    my @machine = $schedulerDB->selectMachineInfo();
    #`ip`,`hostname`,`envhard`,`envsoft`,`switchable`,`group`,`workable`,`role`,`mon`
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

post '/scheduler/submitJob' => sub {
    my $param = params();
    my ( $config, $nice, $group ) = @$param{qw( config nice group )};

    return +{ stat => JSON::false, info => 'nice error' } unless defined $nice && $nice =~ /^\d+$/;
    return +{ stat => JSON::false, info => 'group error' } unless defined $group && $group =~ /^[a-zA-Z0-9]+$/;
    return +{ stat => JSON::false, info => 'config error' } unless defined $config && ref $config eq 'ARRAY';
    my $jobid = $schedulerCtrl->startJob( $config, $nice, $group );
    return +{ stat => JSON::true, data => $jobid }
};

get '/scheduler/listJob' => sub {
    my $param = params();
    my @job = $schedulerDB->selectJobStopedInfo();
    #`id`,`jobid`,`nice`,`group`,`status`
    return +{
        stat => JSON::true,
        data => [ map{ +{ id => $_->[0], jobid => $_->[1], nice => $_->[2], group => $_->[3], status => $_->[4] } }@job ]
    };
};

get '/scheduler/jobstop/:jobid' => sub {
    my $param = params();
    my $jobid = $param->{jobid};
    return +{ stat => JSON::false, info => 'jobid format error' } unless $jobid && $jobid =~ /^J[0-9\.]+$/;
    $schedulerCtrl->stopJob( $jobid );
    return  +{ stat => JSON::true, data => $jobid };
};

get '/scheduler/jobinfo/:jobid' => sub {
    my $param = params();
    my $jobid = $param->{jobid};
    my @task = $schedulerDB->selectTaskByJobid( $jobid );
    #id,jobid,taskid,hostip,status,result,msg,usetime,domain,location,port
    my @job = $schedulerDB->selectJobByJobid( $jobid );
    #id,jobid,nice,group,status
    my $config = eval{ YAML::XS::LoadFile "$opt{scheduler}{conf}/job/$jobid" };

    return +{ stat => JSON::true, data => +{
        config => $config,
        task => [ map{ +{
            id => $_->[0], jobid => $_->[1], taskid => $_->[2],
            hostip => $_->[3], status => $_->[4], result => $_->[5],
            msg => $_->[6], usetime => $_->[7], domain => $_->[8],
            location => $_->[9], port => $_->[10] } }@task ],
        job => +{
            id => $job[0][0], jobid => $job[0][1], nice => $job[0][2],
            group => $job[0][3], status => $job[0][4] }
     } };
};

get '/scheduler/taskinfo/:taskid' => sub {
    my $param = params();
    my $taskid = $param->{taskid};
    my @task = $schedulerDB->selectTaskByTaskid( $taskid );
    #id,jobid,taskid,hostip,status,result,msg,usetime,domain,location,port

    return +{ stat => JSON::true, data => +{
        id => $task[0][0], jobid => $task[0][1],
        taskid => $task[0][2], hostip => $task[0][3],
        status => $task[0][4], result => $task[0][5],
        msg => $task[0][6], usetime => $task[0][7],
        domain => $task[0][8], location => $task[0][9],
        port => $task[0][10], executer => $task[0][11],
     } };
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

get '/scheduler/ingress' => sub {
    my @job = $schedulerDB->selectIngressJob();
    #`id`,`jobid`,`nice`,`group`,`status`,`ingress`
    my %ingress; map{ map{ my @x = split /:/, $_; $ingress{$x[0]}++; }split /,/, $_->[5] }@job;
    template 'scheduler/ingress', +{ ingress => [ sort keys %ingress ] };
};

get '/scheduler/ingress/:domain' => sub {
    my $param = params();
    my $domain = $param->{domain};
    my @job = $schedulerDB->selectIngressJob();
    #`id`,`jobid`,`nice`,`group`,`status`,`ingress`

    my %ingress;
    for my $job ( @job )
    {
        map{
            my @x = split /:/, $_;
            $ingress{$job->[3]}{$job->[1]}++ if $domain eq $x[0];
        }split /,/, $job->[5];
    }

    for my $group (  keys %ingress )
    {
        for my $jobid ( keys %{$ingress{$group}} )
        {
            my @task = $schedulerDB->selectTaskByJobid( $jobid );
            $ingress{$group}{$jobid} = \@task;
        }
    }

    my ( @group, %group )= $schedulerDB->selectIngressMachine();
    #`ip`,`hostname`,`envhard`,`envsoft`,`switchable`,`group`,`workable`,`role`
    map{ push @{$group{$_->[5]}}, $_->[0]; }@group;
    map{ $group{$_} = join ',', @{$group{$_}} }keys %group;
    
    template 'scheduler/ingressInfo', +{ ingress => \%ingress, group => \%group, domain => $domain };
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

any '/mon' => sub {
    eval{ $schedulerDB->mon() if $schedulerDB->isMysql() };
    return $@ ? "ERR:$@" : "ok";
};

true;
