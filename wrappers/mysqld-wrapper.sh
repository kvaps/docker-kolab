#!/bin/bash
d=mysqld
l=/var/log/mysqld.log
trap '{ service $d stop; exit 0; }' EXIT
service $d start
tail -f -n1 $l
