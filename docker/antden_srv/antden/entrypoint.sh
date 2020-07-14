#!/bin/bash

/opt/mydan/dan/bootstrap/bin/bootstrap --start

echo MYDan started.

/opt/AntDen/scripts/init master

/opt/AntDen/bin/antden slave c --start
/opt/AntDen/bin/antden c c --start
/opt/AntDen/bin/antden s c --start
/opt/AntDen/bin/antden d start
echo AntDen started.

sleep 3

/opt/AntDen/bin/antden s am 127.0.0.1 --group antden
echo addMachine 127.0.0.1 done.

sleep 100000000000000
