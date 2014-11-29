#!/bin/bash
service rsyslog start
service postfix start
service httpd start
service mysqld start
service dirsrv start
service cyrus-imapd start
service amavisd start
service clamd start
service wallace start
sleep 10
service kolabd start
service kolab-saslauthd start
