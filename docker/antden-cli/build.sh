#!/bin/bash
VERSION=$1
if [ -z $VERSION ]; then
    VERSION=latest
fi
docker build -t antden/cli:$VERSION .
