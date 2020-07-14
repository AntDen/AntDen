#!/bin/bash
rsync -av ../../../ AntDen/
docker build -t antden/base:latest .
