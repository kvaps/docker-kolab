#!/bin/bash
#
# Directories mapping config.
#
# Example:
#   VOLUMES=(config data log)  - Define /config, /data and /log volumes
#   VOLUME_DATA=(              - Configure /data volume:
#       /var/lib/mysql             map /var/lib/mysql to /data/mysql
#       /var/lib/imap              map /var/lib/imap to /data/imap
#   )
#

VOLUMES=(config data spool log)


VOLUME_CONFIG_STRIP=1
VOLUME_CONFIG=(
    /etc/image/version.conf
    /etc/aliases
    /etc/aliases.db
    /etc/amavisd
    /etc/clamd.conf
    /etc/clamd.d
    /etc/cyrus.conf
    /etc/dirsrv
    /etc/sysconfig/dirsrv-$(hostname -s)
    /etc/sysconfig/mongod
    /etc/sysconfig/mongos
    /etc/fail2ban
    /etc/freshclam.conf
    /etc/httpd
    /etc/imapd.conf
    /etc/imapd.annotations.conf
    /etc/iRony
    /etc/kolab
    /etc/kolab-freebusy
    /etc/mail/spamassassin
    /etc/manticore
    /etc/mongod.conf
    /etc/mongos.conf
    /etc/my.cnf.d
    /etc/nginx
    /etc/opendkim
    /etc/opendkim.conf
    /etc/php.d
    /etc/php-fpm.conf
    /etc/php-fpm.d
    /etc/php.ini
    /etc/pki
    /etc/postfix
    /etc/roundcubemail
    /etc/ssl
)

VOLUME_DATA_STRIP=2
VOLUME_DATA=(
    /var/lib/chwala
    /var/lib/clamav
    /var/lib/dirsrv
    /var/lib/fail2ban
    /var/lib/geoclue
    /var/lib/imap
    /var/lib/iRony
    /var/lib/kolab
    /var/lib/kolab-freebusy
    /var/lib/mongodb
    /var/lib/mysql
    /var/lib/postfix
    /var/lib/roundcubemail
    /var/lib/spamassassin
)

VOLUME_SPOOL_STRIP=2
VOLUME_SPOOL=(
    /var/spool/amavisd
    /var/spool/imap
    /var/spool/mail
    /var/spool/opendkim
    /var/spool/postfix
    /var/spool/pykolab
)

VOLUME_LOG_STRIP=2
VOLUME_LOG=(
    /var/log/chwala
    /var/log/dirsrv
    /var/log/httpd
    /var/log/iRony
    /var/log/kolab
    /var/log/kolab-autoconf
    /var/log/kolab-freebusy
    /var/log/kolab-syncroton
    /var/log/kolab-webadmin
    /var/log/mariadb
    /var/log/mongodb
    /var/log/nginx
    /var/log/php-fpm
    /var/log/roundcubemail
)
