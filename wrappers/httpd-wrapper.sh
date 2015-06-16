#!/bin/bash
d=httpd
l=/var/log/httpd/error_log
trap '{ service $d stop; exit 0; }' EXIT
service $d start ; tail -f -n1 $l
