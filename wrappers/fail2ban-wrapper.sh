#!/bin/bash
d=fail2ban
l=/var/log/messages
g='fail2ban.*\[.*\]:'
trap '{ service $d stop; exit 0; }' EXIT
service $d start
tail -f -n1 $l | grep $g
