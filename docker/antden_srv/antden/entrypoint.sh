#!/bin/bash

/opt/AntDen/bin/antden slave c --start
/opt/AntDen/bin/antden c c --start
/opt/AntDen/bin/antden s c --start
/opt/AntDen/bin/antden d start

/opt/mydan/dan/bootstrap/bin/bootstrap --start

sleep 100000000000000
