#!/bin/bash
d=postfix
l=/var/log/maillog
g='postfix.*\[.*\]:'
trap '{ service $d stop; exit 0; }' EXIT
service $d start
tail -f -n1 $l | grep $g
