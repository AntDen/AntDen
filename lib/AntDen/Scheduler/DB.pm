package AntDen::Scheduler::DB;
use strict;
use warnings;

use base qw( AntDen::Util::DB );

sub define
{
    machine => [
        ip => 'TEXT NOT NULL PRIMARY KEY',
        hostname => 'TEXT NOT NULL',
        group => 'TEXT NOT NULL',
        envhard => 'TEXT NOT NULL',
        envsoft => 'TEXT NOT NULL',
        switchable => 'TEXT NOT NULL',
        workable => 'TEXT NOT NULL',
        role => 'TEXT NOT NULL',
        mon => 'TEXT NOT NULL',
    ],
    resources => [
        ip => 'TEXT NOT NULL',
        name => 'TEXT NOT NULL',
        id => 'TEXT NOT NULL',
        value => 'TEXT NOT NULL',
    ],
    job => [
        id => 'INTEGER PRIMARY KEY AUTOINCREMENT',
        jobid => 'TEXT NOT NULL',
        owner => 'TEXT NOT NULL',
        name => 'TEXT NOT NULL',
        nice => 'INTEGER NOT NULL',
        group => 'TEXT NOT NULL',
        status => 'TEXT NOT NULL',
        ingress => 'TEXT NOT NULL',
    ],
    task => [
        id => 'INTEGER PRIMARY KEY AUTOINCREMENT',
        jobid => 'TEXT NOT NULL',
        taskid => 'TEXT NOT NULL',
        hostip => 'TEXT NOT NULL',
        status => 'TEXT NOT NULL',
        result => 'TEXT NOT NULL',
        msg => 'TEXT NOT NULL',
        usetime => 'TEXT NOT NULL',
        domain => 'TEXT NOT NULL',
        location => 'TEXT NOT NULL',
        port => 'TEXT NOT NULL',
        executer => 'TEXT NOT NULL',
    ],
    user => [
        id => 'INTEGER PRIMARY KEY AUTOINCREMENT',
        name => 'TEXT NOT NULL',
        isadmin => 'INTEGER NOT NULL',
    ],
    auth => [
        id => 'INTEGER PRIMARY KEY AUTOINCREMENT',
        user => 'TEXT NOT NULL',
        group => 'TEXT NOT NULL',
        executer => 'TEXT NOT NULL',
    ],
};

sub stmt
{
    insertMachine => "replace into machine (`ip`,`hostname`,`group`,`envhard`,`envsoft`,`switchable`,`workable`,`role`,`mon`) values(?,?,?,?,?,?,?,?,?)",
    selectMachine => "select `ip`,`hostname`,`envhard`,`envsoft`,`switchable`,`group`,`workable`,`role`,`mon` from machine",

    updateMachineAttr_workable => "update machine set `workable`=? where ip=?",
    updateMachineAttr_mon => "update machine set `mon`=? where ip=?",

    updateJobAttr_nice => "update job set `nice`=? where jobid=?",

    insertResources => "insert into `resources` ( `ip`,`name`,`id`,`value`) values(?,?,?,?)",
    selectResources => "select `ip`,`name`,`id`,`value` from resources",
    deleteResourcesByIp => "delete from resources where ip=?",

    insertJob => "insert into job ( `jobid`,`owner`,`name`,`nice`,`group`,`status`,`ingress` ) values(?,?,?,?,?,'queuing',?)",
    selectJobWork => "select `id`,`jobid`,`owner`,`name`,`nice`,`group`,`status` from job where status!='stoped'",
    updateJobStatus => "update job set `status`=? where jobid=?",
    jobStoped => "update job set `status`='stoped' where jobid=?",

    insertTask => "insert into task ( `jobid`,`taskid`,`hostip`,`status`,`result`,`msg`,`usetime`,`domain`,`location`,`port`,`executer` ) values(?,?,?,'init','','','',?,?,?,?)",
    selectTaskWork => "select `id`,`jobid`,`taskid`,`hostip`,`status`,`result`,`msg` from task where status !='stoped'",
    selectTaskStatusByJobid => "select status from task where jobid=?",
    updateTaskStatus => "update task set `status`=?,result=?,msg=? where taskid=? and jobid=?",
    updateTaskResult => "update task set `status`=?,result=?,msg=?,usetime=? where taskid=? and jobid=?",

    #dashboard
    selectMachineInfo => "select `ip`,`hostname`,`envhard`,`envsoft`,`switchable`,`group`,`workable`,`role`,`mon` from machine",
    selectMachineInfoByUser => "select `ip`,`hostname`,`envhard`,`envsoft`,`switchable`,machine.group,`workable`,`role`,`mon` from machine,auth where machine.group=auth.group and user=?",
    selectMachineIpByUser => "select `ip` from machine,auth where machine.group=auth.group and user=?",
    selectResourcesInfoByUser => "select resources.ip,`name`,resources.id,`value` from resources,machine,auth where resources.ip=machine.ip and machine.group=auth.group and auth.user=?",

    selectJobWorkInfo => "select `id`,`jobid`,`owner`,`name`,`nice`,`group`,`status`,`ingress` from job where status!='stoped'",
    selectJobWorkInfoByUser => "select `id`,`jobid`,`owner`,`name`,`nice`,`group`,`status`,`ingress` from job where status!='stoped' and owner=?",
    selectJobStopedInfo => "select `id`,`jobid`,`owner`,`name`,`nice`,`group`,`status` from job",

    selectTaskByJobid => "select id,jobid,taskid,hostip,status,result,msg,usetime,domain,location,port from task where jobid=?",
    selectJobByJobid => "select id,jobid,nice,`group`,status from job where jobid=?",

    selectIngressJob => "select `id`,`jobid`,`nice`,`group`,`status`,`ingress` from job where status!='stoped' and ingress != ''",
    selectIngressJobByUser => "select `id`,`jobid`,`nice`,`group`,`status`,`ingress` from job where status!='stoped' and ingress != '' and owner=?",
    selectIngress => "select `id`,`jobid`,`nice`,`group`,`status`,`ingress` from job where status!='stoped' and ingress != ''",
    selectIngressMachine => "select `ip`,`hostname`,`envhard`,`envsoft`,`switchable`,`group`,`workable`,`role` from machine where role='ingress'",

    selectIsAdmin => "select id,name,isadmin from user where name=?",
    selectIsAdminAll => "select id,name,isadmin from user",

    insertAuth => "insert into `auth` (`user`,`group`,`executer`) values(?,?,?)",
    selectAuth => "select `id`,`user`,`group`,`executer` from auth",
    selectAuthByUser => "select `executer` from auth where user=? and `group`=?",
    deleteAuthById => "delete from `auth` where id=?",
    deleteAdminById => "delete from `user` where id=? and isadmin=1",
    selectMon => "select count(*) from machine",

    insertAdmin => "insert into `user` (`name`,`isadmin`) values(?,1)",
    #api
    selectTaskByTaskid => "select id,jobid,taskid,hostip,status,result,msg,usetime,domain,location,port,executer from task where taskid=?",
    selectJobStopedInfoByOwnerPage => "select `id`,`jobid`,`owner`,`name`,`nice`,`group`,`status` from job where owner=? ORDER BY id desc limit ?,?",
    selectJobStopedInfoByOwner => "select `id`,`jobid`,`owner`,`name`,`nice`,`group`,`status` from job where owner=? ORDER BY id desc limit 20",
    selectJobByJobidAndOwner => "select `id` from job where jobid=? and owner=?",
}

1;
