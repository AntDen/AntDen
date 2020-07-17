#!/bin/bash
os=$(uname)
echo "os: $os"
if [ "X$os" != 'XLinux'  ];then
    echo "Not supported you os, Only allowed to run on centos7"
    exit
fi


os=$(cat /etc/redhat-release|sed -r 's/(\w+)\s+.* ([0-9]+)\..*/\1\2/')

echo "os: $os"
if [ "X$os" != 'XCentOS7'  ];then
    echo "Not supported you os, Only allowed to run on centos7"
    exit
fi

docker --version 2>/dev/null
if [ $? != 0 ];then
    curl -sL get.docker.io|bash
    service docker start
    docker --version
fi

dockerversion=$(docker --version 2>/dev/null|sed -r 's/.* ([0-9]+)\..*/\1/')
echo "docker version: $dockerversion"

if [ $dockerversion -lt 19 ]; then
    echo "The version of docker is too low and needs to be updated to version 19"
    exit

fi

docker-compose --version 2>/dev/null
if [ $? != 0 ];then
    curl -L https://github.com/docker/compose/releases/download/1.8.0/run.sh > /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    docker-compose --version
fi

git --version 2>/dev/null|| yum install git -y
if [ ! -d AntDen ];then
    git clone https://github.com/data-o/AntDen
fi

cd AntDen || exit 1

./control srv up -d

if [ "X$elk" != "X" ]; then
    ./control srv up -d
fi
