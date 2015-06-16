#!/bin/bash
d=kolab-saslauthd
trap '{ sleep 2; service $d stop; exit 0; }' EXIT
service $d start
sleep infinity
