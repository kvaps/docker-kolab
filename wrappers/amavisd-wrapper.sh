#!/bin/bash
d=amavisd
l=/var/log/maillog
g='amavis.*\[.*\]:'
trap '{ service $d stop; exit 0; }' EXIT
service $d start
tail -f -n1 $l | grep $g
