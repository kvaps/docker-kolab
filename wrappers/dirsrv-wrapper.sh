#!/bin/bash
d=dirsrv
l=/var/log/dirsrv/slapd-*/errors
trap '{ service $d stop; exit 0; }' EXIT
service $d start
tail -f -n1 $l
