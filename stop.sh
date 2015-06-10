#!/bin/bash
#service fail2ban stop
#service opendkim stop
service kolabd stop
service kolab-saslauthd stop
sleep 2
service postfix stop
service httpd stop
#service nginx stop
#service php-fpm stop
service mysqld stop
service dirsrv stop
service cyrus-imapd stop
service amavisd stop
service clamd stop
service wallace stop
service rsyslog stop
