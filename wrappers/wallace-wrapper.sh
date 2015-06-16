#!/bin/bash
d=wallace
trap '{ service $d stop; exit 0; }' EXIT
service $d start
sleep infinity
