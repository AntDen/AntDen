package api::antdencli;
use Dancer ':syntax';
use POSIX;
use FindBin qw( $RealBin );
use JSON;

set serializer => 'JSON';
set show_errors => 1;

our $VERSION = '0.1';
our %addr;

BEGIN{
    my @addr = `cat $RealBin/../whitelist`;
    chomp @addr;
    %addr = map{ $_ => 1 }@addr;
};

post '/api/antdencli/submitJob' => sub {
    my $addr = request->env->{REMOTE_ADDR};
    return( 'Unauthorized:' . $addr ) unless $addr{$addr} || $addr =~ /^172\./;
    my $param = params();
    my ( $config, $nice, $group, $owner, $name ) = @$param{qw( config nice group owner name )};

    return +{ stat => JSON::false, info => 'nice error' } unless defined $nice && $nice =~ /^\d+$/;
    return +{ stat => JSON::false, info => 'group error' } unless defined $group && $group =~ /^[a-zA-Z0-9]+$/;
    return +{ stat => JSON::false, info => 'owner error' } unless defined $owner && $owner =~ /^[a-zA-Z0-9_\-\.@]+$/;
    return +{ stat => JSON::false, info => 'name error' } unless defined $name && $name =~ /^[a-zA-Z0-9_\-\.]+$/;
    return +{ stat => JSON::false, info => 'config error' } unless defined $config && ref $config eq 'ARRAY';
    my ( @auth, $err )= $dashboard::schedulerDB->selectAuthByUser( $owner, $group );
    #`executer`
    my %auth; map{ $auth{$_->[0]} = 1; }@auth;
    map{ $err = "no auth: $owner $group $_->{executer}{name}" unless $auth{$_->{executer}{name}} }@$config;
    return +{ stat => JSON::false, info => "err: $err" } if $err;
     
    my $jobid = $dashboard::schedulerCtrl->startJob( $config, $nice, $group, $owner, $name );
    return +{ stat => JSON::true, data => $jobid }
};

get '/api/antdencli/listJob' => sub {
    my $addr = request->env->{REMOTE_ADDR};
    return( 'Unauthorized:' . $addr ) unless $addr{$addr} || $addr =~ /^172\./;
    my $param = params();
    my $owner = $param->{owner};
    return return +{ stat => JSON::false, info => 'jobid format error' } unless $owner && $owner =~ /^[a-zA-Z0-9_\-\.@]+$/;
    my @job = $dashboard::schedulerDB->selectJobStopedInfoByOwner( $owner );
    #`id`,`jobid`,`owner`,`name`,`nice`,`group`,`status`
    return +{
        stat => JSON::true,
        data => [ map{ +{ id => $_->[0], jobid => $_->[1], owner => $_->[2], name => $_->[3], nice => $_->[4], group => $_->[5], status => $_->[6] } }@job ]
    };
};

get '/api/antdencli/jobstop/:jobid' => sub {
    my $param = params();
    my ( $jobid, $owner ) = @$param{qw(jobid owner)};
    return +{ stat => JSON::false, info => 'jobid format error' } unless $jobid && $jobid =~ /^J[0-9\.]+$/;

    return +{ stat => JSON::false, info => 'noauth' }
        unless my @m = $dashboard::schedulerDB->selectJobByJobidAndOwner( $jobid, $owner );

    $dashboard::schedulerCtrl->stopJob( $jobid );
    return  +{ stat => JSON::true, data => $jobid };
};

get '/api/antdencli/jobinfo/:jobid' => sub {
    my $addr = request->env->{REMOTE_ADDR};
    return( 'Unauthorized:' . $addr ) unless $addr{$addr} || $addr =~ /^172\./;
    my $param = params();
    my ( $jobid, $owner ) = @$param{qw(jobid owner)};

    return +{ stat => JSON::false, info => 'noauth' }
        unless my @m = $dashboard::schedulerDB->selectJobByJobidAndOwner( $jobid, $owner );

    my @task = $dashboard::schedulerDB->selectTaskByJobid( $jobid );
    #id,jobid,taskid,hostip,status,result,msg,usetime,domain,location,port
    my @job = $dashboard::schedulerDB->selectJobByJobid( $jobid );
    #id,jobid,nice,group,status
    my $config = eval{ YAML::XS::LoadFile "$dashboard::opt{scheduler}{conf}/job/$jobid" };

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

get '/api/antdencli/taskinfo/:taskid' => sub {
    my $addr = request->env->{REMOTE_ADDR};
    return( 'Unauthorized:' . $addr ) unless $addr{$addr} || $addr =~ /^172\./;
    my $param = params();
    my $taskid = $param->{taskid};
    my @task = $dashboard::schedulerDB->selectTaskByTaskid( $taskid );
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

get '/api/antdencli/resources' => sub {
    my $addr = request->env->{REMOTE_ADDR};
    return( 'Unauthorized:' . $addr ) unless $addr{$addr} || $addr =~ /^172\./;
    my $param = params();

    my @machine = $dashboard::schedulerDB->selectMachineInfoByUser( $param->{owner} );
    #`ip`,`hostname`,`envhard`,`envsoft`,`switchable`,`group`,`workable`,`role`,`mon`

    my @resources = $dashboard::schedulerDB->selectResourcesInfoByUser( $param->{owner} );
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
        map{ $use{$_} += $v->{$_} if $v->{$_} =~ /^\d+$/ || $v->{$_} =~ /^\d+\.\d+$/ }keys %$v;
    }

    $t{health} = scalar @machine;
    $t{load} = int( $t{CPU} / 1024 ) if $t{CPU};

    my @total = map{ [ $_, $use{$_}, $t{$_} ] }sort keys %t;
    return +{ stat => JSON::true, data => +{
        machine => [ map{ +{
            ip => $_->[0], hostname => $_->[1],
            envhard => $_->[2], envsoft => $_->[3],
            switchable => $_->[4], group => $_->[5],
            workable => $_->[6], role => $_->[7],
            resources => $_->[9], mon => $_->[8]
      } }@machine ], total => \@total
    } };
};

get '/api/antdencli/datasets' => sub {
    my $addr = request->env->{REMOTE_ADDR};
    return( 'Unauthorized:' . $addr ) unless $addr{$addr} || $addr =~ /^172\./;
    my $param = params();

    my @datasets = $dashboard::schedulerDB->selectDatasetsByUser( $param->{owner} );
    #`id`,`name`,`info`,`type`,`group`,`token`

    return +{ stat => JSON::true, data => [ map{
        +{
            id => $_->[0], name => $_->[1],
            info => $_->[2], type => $_->[3],
            group => $_->[4], token => $_->[5]
        }
    } @datasets] };
};

true;
