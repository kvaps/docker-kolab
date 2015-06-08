#!/bin/bash
service kolabd stop
service kolab-saslauthd stop
sleep 2
service postfix stop
#service httpd stop
service nginx start
service php-fpm start
service mysqld stop
service dirsrv stop
service cyrus-imapd stop
service amavisd stop
service clamd stop
service wallace stop
service rsyslog stop
