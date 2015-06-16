#!/bin/bash
d=kolabd
l=/var/log/kolab/pykolab.log
trap '{ service $d stop; exit 0; }' EXIT 
sleep 10
service $d start 
tail -f -n1 $l
