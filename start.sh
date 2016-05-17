#!/bin/bash

chk_env() {
    eval env=\$$1
    val=${env:-$2}
    if [ -z $val ]; then
        echo "err:  Enviroment vaiable \$$1 is not set."
        exit 1
    fi  
    export "$1"="$val"
}

load_defaults() {

    # Options
    chk_env  WEBSERVER             "nginx"
    chk_env  FORCE_HTTPS           true
    chk_env  NGINX_CACHE           false
    chk_env  SPAM_SIEVE            true
    chk_env  SPAM_SIEVE_TIMEOUT    "15m"
    chk_env  FAIL2BAN              true
    chk_env  DKIM                  true
    chk_env  CERT_PATH             "/etc/pki/tls/kolab"

    # Sizes
    chk_env  MAX_MEMORY_SIZE       "256M"
    chk_env  MAX_FILE_SIZE         "30M"
    chk_env  MAX_MAIL_SIZE         "30M"
    chk_env  MAX_MAILBOX_SIZE      "50M"
    chk_env  MAX_BODY_SIZE         "50M"

    # Services
    chk_env SERVICE_RSYSLOG         true
    chk_env SERVICE_HTTPD           true
    chk_env SERVICE_NGINX           false
    chk_env SERVICE_PHP_FPM         false
    chk_env SERVICE_MYSQLD          true
    chk_env SERVICE_DIRSRV          true
    chk_env SERVICE_POSTFIX         true
    chk_env SERVICE_CYRUS_IMAPD     true
    chk_env SERVICE_AMAVISD         true
    chk_env SERVICE_CLAMD           true
    chk_env SERVICE_WALLACE         true
    chk_env SERVICE_KOLABD          true
    chk_env SERVICE_KOLAB_SASLAUTHD true
    chk_env SERVICE_OPENDKIM        false
    chk_env SERVICE_FAIL2BAN        false
    chk_env SERVICE_SET_SPAM_SIEVE  false

    volumes=(config data log)

    config_dirs=(
        /etc/dirsrv
        /etc/fail2ban
        /etc/httpd
        /etc/my.cnf
        /etc/cyrus.conf
        /etc/imapd.conf
        /etc/imapd.annotations.conf
        /etc/kolab
        /etc/kolab-freebusy
        /etc/nginx
        /etc/opendkim
        /etc/opendkim.conf
        /etc/php-fpm.d
        /etc/php-fpm.conf
        /etc/php.d
        /etc/php.ini
        /etc/postfix
        /etc/roundcubemail
        /etc/sasldb2
        /etc/supervisord.conf
        /etc/clamd.conf
        /etc/clamd.d
        /etc/freshclam.conf
        /etc/iRony
        /etc/ssl
        /etc/mailname
        /etc/mail
        /etc/pki
    )
    
    data_dirs=(
        /var/lib/mysql
        /var/lib/dirsrv
        /var/lib/imap
        /var/lib/nginx
        /var/lib/spamassassin
        /var/lib/clamav
        /var/spool
    )
    
    log_dirs=(
        /var/log/chwala
        /var/log/clamav
        /var/log/dirsrv
        /var/log/httpd
        /var/log/iRony
        /var/log/kolab
        /var/log/kolab-freebusy
        /var/log/kolab-syncroton
        /var/log/kolab-webadmin
        /var/log/maillog
        /var/log/messages
        /var/log/mysqld.log
        /var/log/nginx
        /var/log/php-fpm
        /var/log/roundcubemail
        /var/log/supervisor
    )
}

print_spaces() {
    spaces_count=$( echo $2 - ${#1} | bc)
    eval 'printf "%0.s " {1..'$spaces_count'}'
}

chk_dirs() {

    echo "Processing folders:"
    echo "STORAGE   FOLDER                   ACTION"
    echo "------------------------------------------------"
    for storage in "${volumes[@]}"; do

        # Default config dirs
        configdirs=($(eval echo '${'$storage'_dirs[@]}'))
        # User definded dirs
        userdirs=($(env | grep -P '^'${storage^^}'_DIR_[0-9]+=' | cut -d= -f2-))

        for dir in "${configdirs[@]}" "${userdirs[@]}"; do
           dirname=$(basename $dir)
           newdir="/${storage}${dirname}"

           echo -en "$storage"
           print_spaces $storage 10
           echo -en "$dirname"
           print_spaces $dirname 25

           if [ ! -e ${newdir} ]; then
               echo -n '(copy) '
               #cp -Lrp $dir ${newdir} || exit 1
           fi
           if [ ! -e ${newdir} ]; then
               echo -n '(link) '

               # If $dir is symbolyc link
               if [ -L $dir ]; then
                   linkdir="$(readlink $dir)"
                   if [ "$linkdir" = "$newdir" ]; then
                       echo 'error: duplicate dirname!'
                       exit 1
                   #else
                       #rm -rf $linkdir
                       #ln -s $newdir $linkdir || exit 1
                   fi
               fi

               #rm -rf $dir
               #ln -s $newdir $dir || exit 1
           fi
           echo

        done
    done
}
