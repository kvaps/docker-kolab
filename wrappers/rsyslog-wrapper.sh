#!/bin/bash
d=rsyslog
l=/var/log/messages
g=rsyslogd:
trap '{ service $d stop; exit 0; }' EXIT 
service $d start 
tail -f -n 1 $l | grep $g
