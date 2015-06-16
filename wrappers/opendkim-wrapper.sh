#!/bin/bash
d=opendkim
l=/var/log/maillog
g='opendkim.*\[.*\]:'
trap '{ service $d stop; exit 0; }' EXIT
service $d start
tail -f -n1 $l | grep $g
