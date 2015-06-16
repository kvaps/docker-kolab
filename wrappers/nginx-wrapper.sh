#!/bin/bash
d=nginx
l=/var/log/nginx/error.log
trap '{ service $d stop; exit 0; }' EXIT 
service $d start 
tail -f -n1 $l
