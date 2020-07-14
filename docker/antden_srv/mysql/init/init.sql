create database antden;

CREATE TABLE `user` (
    `id` int(32) unsigned NOT NULL AUTO_INCREMENT,
    `name` varchar(255) NOT NULL,
    `isadmin` int(32) NOT NULL,
    PRIMARY KEY (`id`)
);
insert into user (`name`,`isadmin`)values('antden','2');
