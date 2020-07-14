create database antden;

use antden;

CREATE TABLE `user` (
    `id` int(32) unsigned NOT NULL AUTO_INCREMENT,
    `name` varchar(255) NOT NULL,
    `isadmin` int(32) NOT NULL,
    PRIMARY KEY (`id`)
);
insert into user (`name`,`isadmin`)values('antden','2');

CREATE TABLE `auth` (
  `id` int(32) unsigned NOT NULL AUTO_INCREMENT,
  `user` varchar(255) NOT NULL,
  `group` varchar(255) NOT NULL,
  `executer` varchar(255) NOT NULL,
  PRIMARY KEY (`id`)
);

insert into auth (`user`,`group`,`executer`)values('antden','antden','cmd');
insert into auth (`user`,`group`,`executer`)values('antden','foo','cmd');
