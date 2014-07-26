#!/bin/bash
service kolabd stop
service kolab-saslauthd stop
sleep 2
service postfix stop
service httpd stop
service mysqld stop
service dirsrv stop
service cyrus-imapd stop
service amavisd stop
service clamd stop
service rsyslog stop
