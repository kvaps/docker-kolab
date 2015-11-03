#!/bin/bash

# Check first parameter
if [ -z $1 ]; then
    echo "Service is not set"
    exit 1
fi

# Set trap and start service
trap "{ service $1 stop; exit 0; }" EXIT
service $1 start

# Set output to log-file and grep it
if [ -z $2 ]; then
    sleep infinity
else
    if [ -z $3 ]; then
        tail -f -n1 $2
    else
        tail -f -n1 $2 | grep $3
    fi
fi
