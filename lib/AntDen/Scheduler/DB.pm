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
    selectResourcesInfo => "select `ip`,`name`,`id`,`value` from resources",


    selectJobWorkInfo => "select `id`,`jobid`,`owner`,`name`,`nice`,`group`,`status`,`ingress` from job where status!='stoped'",
    selectJobStopedInfo => "select `id`,`jobid`,`owner`,`name`,`nice`,`group`,`status` from job",

    selectTaskByJobid => "select id,jobid,taskid,hostip,status,result,msg,usetime,domain,location,port from task where jobid=?",
    selectJobByJobid => "select id,jobid,nice,`group`,status from job where jobid=?",

    selectIngressJob => "select `id`,`jobid`,`nice`,`group`,`status`,`ingress` from job where status!='stoped' and ingress != ''",
    selectIngress => "select `id`,`jobid`,`nice`,`group`,`status`,`ingress` from job where status!='stoped' and ingress != ''",
    selectIngressMachine => "select `ip`,`hostname`,`envhard`,`envsoft`,`switchable`,`group`,`workable`,`role` from machine where role='ingress'",

    mon => "select count(*) from machine",

    #api
    selectTaskByTaskid => "select id,jobid,taskid,hostip,status,result,msg,usetime,domain,location,port,executer from task where taskid=?",
    selectJobStopedInfoByOwner => "select `id`,`jobid`,`owner`,`name`,`nice`,`group`,`status` from job where owner=?",
}

1;
