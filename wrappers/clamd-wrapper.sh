#!/bin/bash
d=clamd
l=/var/log/clamav/clamd.log
trap '{ service $d stop; exit 0; }' EXIT
service $d start 
tail -f -n1 $l
