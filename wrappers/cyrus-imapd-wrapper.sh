#!/bin/bash
d=cyrus-imapd
l=/var/log/maillog
g='[master\|pop3\|imap].*\[.*\]:'
trap '{ service $d stop; exit 0; }' EXIT 
service $d start
tail -f -n1 $l
