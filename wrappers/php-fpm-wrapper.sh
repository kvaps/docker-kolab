#!/bin/bash
d=php-fpm
l=/var/log/php-fpm/error.log
trap '{ service $d stop; exit 0; }' EXIT
service $d start
tail -f -n1 $l
