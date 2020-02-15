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
        nice => 'INTEGER NOT NULL',
        group => 'TEXT NOT NULL',
        status => 'TEXT NOT NULL',
    ],
    task => [
        id => 'INTEGER PRIMARY KEY AUTOINCREMENT',
        jobid => 'TEXT NOT NULL',
        taskid => 'TEXT NOT NULL',
        hostip => 'TEXT NOT NULL',
        status => 'INTEGER NOT NULL',
        result => 'TEXT NOT NULL',
        msg => 'TEXT NOT NULL',
        usetime => 'TEXT NOT NULL',
    ],
};

sub stmt
{
    insertMachine => "replace into machine (`ip`,`hostname`,`group`,`envhard`,`envsoft`,`switchable`,`workable`,`role`) values(?,?,?,?,?,?,?,?)",
    selectMachine => "select `ip`,`hostname`,`envhard`,`envsoft`,`switchable`,`group`,`workable`,`role` from machine",

    updateMachineAttr_workable => "update machine set `workable`=? where ip=?",
    updateJobAttr_nice => "update job set `nice`=? where jobid=?",

    insertResources => "insert into `resources` ( `ip`,`name`,`id`,`value`) values(?,?,?,?)",
    selectResources => "select `ip`,`name`,`id`,`value` from resources",
    deleteResourcesByIp => "delete from resources where ip=?",

    insertJob => "insert into job ( `jobid`,`nice`,`group`,`status` ) values(?,?,?,'queuing')",
    selectJob => "select `id`,`jobid`,`nice`,`group`,`status` from job",
    selectJobWork => "select `id`,`jobid`,`nice`,`group`,`status` from job where status!='stoped'",
    updateJobStatus => "update job set `status`=? where jobid=?",

    insertTask => "insert into task ( `jobid`,`taskid`,`hostip`,`status`,`result`,`msg`,`usetime` ) values(?,?,?,'init','','','')",
    selectTask => "select `id`,`jobid`,`taskid`,`hostip`,`status`,`result`,`msg` from task",
    selectTaskWork => "select `id`,`jobid`,`taskid`,`hostip`,`status`,`result`,`msg` from task where status !='stoped'",
    selectTaskStatusByJobid => "select status from task where jobid=?",
    updateTaskStatus => "update task set `status`=?,result=?,msg=? where taskid=? and jobid=?",
    updateTaskResult => "update task set `status`=?,result=?,msg=?,usetime=? where taskid=? and jobid=?",
}

1;
