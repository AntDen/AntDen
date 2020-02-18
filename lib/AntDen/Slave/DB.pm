package AntDen::Slave::DB;
use strict;
use warnings;

use base qw( AntDen::Util::DB );

sub define
{
    task => [
        id => 'INTEGER PRIMARY KEY AUTOINCREMENT',
        jobid => 'TEXT NOT NULL',
        taskid => 'TEXT NOT NULL UNIQUE',
        status => 'INTEGER NOT NULL', 
        expect => 'INTEGER NOT NULL', 
        executeid => 'TEXT NOT NULL',
        result => 'TEXT NOT NULL',
        msg => 'TEXT NOT NULL',
        starttime => 'TEXT NOT NULL',
        weight => 'INTEGER NOT NULL', 
    ]
}

sub stmt
{
    startTask => "insert into `task` (`jobid`,`taskid`,`status`, `expect`, `executeid`,`result`,`msg`,`starttime`,`weight`) values(?,?,?,?,'','','',?,?)",
    stopTask => "update task set expect=? where taskid=?",

    selectTask => "select `jobid`,`taskid`,`status`,`expect`,`executeid`,`weight` from task",

    updateExecuteid => "update task set executeid=?,status=? where taskid=?",
    updateTaskSR => "update task set executeid='null',status=?,result=? where taskid=?",
    updateTaskStatus => "update task set status=? where taskid=?",
    updateTaskResult => "update task set result=? where taskid=?",
    updateTaskMsg => "update task set msg=? where taskid=?",

    selectTaskByTaskid => "select `jobid`,`status`,`result`,`msg`,`starttime` from task where taskid=?",
    deleteTask => "delete from task where taskid=?",
}

1;
