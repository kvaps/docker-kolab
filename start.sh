#!/bin/bash
service rsyslog start
service postfix start
service httpd start
#service nginx start
#service php-fpm start
service mysqld start
service dirsrv start
service cyrus-imapd start
service amavisd start
service clamd start
service wallace start
sleep 10
service kolabd start
service kolab-saslauthd start
#service opendkim start
#service fail2ban start
