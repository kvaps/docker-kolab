#!/bin/bash
usage ()
{
     echo
     echo "Usage:    ./setup.sh [ARGUMENT]"
     echo
     echo "Arguments:"
     echo "    kolab                 - Configure Kolab"
     echo "    amavis                - Configure amavis"
     echo "    nginx                 - Configure nginx"
     echo "    nginx_cache           - Configure nginx caching"
     echo "    ssl                   - Configure SSL using your certs"
     echo "    fail2ban              - Configure Fail2ban"
     echo "    dkim                  - Configure OpenDKIM"
     echo "    larry	             - Set Larry skin as default"
     echo "    zipdownload           - Configure zipdownload plugin for roundcube"
     echo
     exit
}

get_config()
{
    while IFS="=" read var val
    do
        if [[ $var == \[*] ]]
        then
            section=`echo "$var" | tr -d "[] "`
        elif [[ $val ]]
        then
            if [[ $val == "random" ]]
            then
		random_pwd="$(cat /dev/urandom | env LC_CTYPE=C tr -dc a-zA-Z0-9 | head -c 16; echo)"	# gen pass
                eval $section"_"$var=$random_pwd
		sed -i "/\(^"$var"=\).*/ s//\1"$random_pwd"/ " $1	#save generated pass to settings.ini
            else
                eval $section"_"$var="$val"
            fi
        fi
    done < $1
}

mount_dirs()
{
    echo "info:  start mounting folders to attached volume"

    mkdir -p /data/mysql
    mkdir -p /data/dirsrv
    mkdir -p /data/imap
    mkdir -p /data/spamassassin
    mkdir -p /data/clamav
    mkdir -p /data/spool
    mkdir -p /data/logs

    mount -o bind /data/mysql /var/lib/mysql/
    mount -o bind /data/dirsrv /var/lib/mysql/
    mount -o bind /data/imap /var/lib/imap
    mount -o bind /data/spamassassin /var/lib/spamassassin
    mount -o bind /data/clamav /var/lib/clamav/
    mount -o bind /data/spool /var/spool
    mount -o bind /data/logs /var/log

    echo "info:  finished mounting folders to attached volume"
}

fix_fdirs()
{
    echo "info:  start fixing folders and files on attached volume"

    mount_dirs
    
    # create folders on attached volumes
    mkdir -p /var/spool/amavisd
    mkdir -p /var/spool/imap
    mkdir -p /var/spool/mail
    mkdir -p /var/spool/opendkim
    mkdir -p /var/spool/postfix
    mkdir -p /var/spool/pykolab
    
    mkdir -p /var/log/chwala
    mkdir -p /var/log/clamav
    mkdir -p /var/log/dirsrv
    mkdir -p /var/log/httpd
    mkdir -p /var/log/iRony
    mkdir -p /var/log/kolab
    mkdir -p /var/log/kolab-freebusy
    mkdir -p /var/log/kolab-syncroton
    mkdir -p /var/log/kolab-webadmin
    mkdir -p /var/log/nginx
    mkdir -p /var/log/php-fpm
    mkdir -p /var/log/roundcubemail
    mkdir -p /var/log/supervisor
    
    
    # create new log files
    touch /var/log/maillog
    touch /var/log/messages
    touch /var/log/mysqld.log
    touch /var/log/php-fpm/error.log
    touch /var/log/httpd/error_log
    touch /var/log/nginx/error.log
    touch /var/log/kolab/pykolab.log
    touch /var/log/clamav/clamd.log
    touch /var/log/roundcubemail/userlogins
    touch /var/log/iRony/userlogins
    touch /var/log/chwala/userlogins
    touch /var/log/kolab-syncroton/userlogins

    # fix permissons
    chown cyrus:mail /var/lib/imap
    chown mysql:mysql /var/lib/mysql
    
    chown amavis:amavis /var/spool/amavisd
    chown cyrus:mail /var/spool/imap
    chown root:mail /var/spool/mail
    chown opendkim:opendkim /var/spool/opendkim
    chown kolab:kolab /var/spool/pykolab
    
    chown mysql:mysql /var/log/mysqld.log
    chown apache:apache /var/log/chwala
    chown clam:clam /var/log/clamav
    chown apache:apache /var/log/iRony
    chown kolab:kolab-n /var/log/kolab
    chown root:apache /var/log/kolab-freebusy
    chown apache:apache /var/log/kolab-syncroton
    chown apache:apache /var/log/kolab-webadmin
    chown nginx:nginx /var/log/nginx
    chown apache:root /var/log/php-fpm
    chown root:apache /var/log/roundcubemail

    echo "info:  finished fixing folders and files on attached volume"
}

configure_supervisor()
{
    echo "info:  start configuring Supervisor"

    cat > /bin/rsyslog-wrapper.sh << EOF
#!/bin/bash
d=rsyslog
l=/var/log/messages
g=rsyslogd:
trap '{ service \$d stop; exit 0; }' EXIT 
service \$d start 
tail -f -n 1 \$l | grep \$g
EOF

    cat > /bin/nginx-wrapper.sh << EOF
#!/bin/bash
d=nginx
l=/var/log/nginx/error.log
trap '{ service \$d stop; exit 0; }' EXIT 
service \$d start 
tail -f -n1 \$l
EOF

    cat > /bin/httpd-wrapper.sh << EOF
#!/bin/bash
d=httpd
l=/var/log/httpd/error_log
trap '{ service \$d stop; exit 0; }' EXIT
service \$d start ; tail -f -n1 \$l
EOF

    cat > /bin/php-fpm-wrapper.sh << EOF
#!/bin/bash
d=php-fpm
l=/var/log/php-fpm/error.log
trap '{ service \$d stop; exit 0; }' EXIT
service \$d start
tail -f -n1 \$l
EOF

    cat > /bin/mysqld-wrapper.sh << EOF
#!/bin/bash
d=mysqld
l=/var/log/mysqld.log
trap '{ service \$d stop; exit 0; }' EXIT
service \$d start
tail -f -n1 \$l
EOF

    cat > /bin/dirsrv-wrapper.sh << EOF
#!/bin/bash
d=dirsrv
l=/var/log/dirsrv/slapd-*/errors
trap '{ service \$d stop; exit 0; }' EXIT
service \$d start
tail -f -n1 \$l
EOF

    cat > /bin/postfix-wrapper.sh << EOF
#!/bin/bash
d=postfix
l=/var/log/maillog
g='postfix.*\[.*\]:'
trap '{ service \$d stop; exit 0; }' EXIT
service \$d start
tail -f -n1 \$l | grep \$g
EOF

    cat > /bin/cyrus-imapd-wrapper.sh << EOF
#!/bin/bash
d=cyrus-imapd
l=/var/log/maillog
g='[master\|pop3\|imap].*\[.*\]:'
trap '{ service \$d stop; exit 0; }' EXIT 
service \$d start
tail -f -n1 \$l
EOF

    cat > /bin/amavisd-wrapper.sh << EOF
#!/bin/bash
d=amavisd
l=/var/log/maillog
g='amavis.*\[.*\]:'
trap '{ service \$d stop; exit 0; }' EXIT
service \$d start
tail -f -n1 \$l | grep \$g
EOF

    cat > /bin/clamd-wrapper.sh << EOF
#!/bin/bash
d=clamd
l=/var/log/clamav/clamd.log
trap '{ service \$d stop; exit 0; }' EXIT
service \$d start 
tail -f -n1 \$l
EOF

    cat > /bin/wallace-wrapper.sh << EOF
#!/bin/bash
d=wallace
trap '{ service \$d stop; exit 0; }' EXIT
service \$d start
sleep infinity
EOF

    cat > /bin/kolabd-wrapper.sh << EOF
#!/bin/bash
d=kolabd
l=/var/log/kolab/pykolab.log
trap '{ service \$d stop; exit 0; }' EXIT 
sleep 10
service \$d start 
tail -f -n1 \$l
EOF

    cat > /bin/kolab-saslauthd-wrapper.sh << EOF
#!/bin/bash
d=kolab-saslauthd
trap '{ sleep 2; service \$d stop; exit 0; }' EXIT
service \$d start
sleep infinity
EOF

    cat > /bin/opendkim-wrapper.sh << EOF
#!/bin/bash
d=opendkim
l=/var/log/maillog
g='opendkim.*\[.*\]:'
trap '{ service \$d stop; exit 0; }' EXIT
service \$d start
tail -f -n1 \$l | grep \$g
EOF

    cat > /bin/fail2ban-wrapper.sh << EOF
#!/bin/bash
d=fail2ban
l=/var/log/messages
g='fail2ban.*\[.*\]:'
trap '{ service \$d stop; exit 0; }' EXIT
service \$d start
tail -f -n1 \$l | grep \$g
EOF

    cat > /bin/set_spam_acl.sh << EOF 
#!/bin/bash
set_spam_acl ()
{
    kolab sam user/%/Spam@$(hostname -d) anyone p
    sleep 15m 
    set_spam_acl
}
set_spam_acl
EOF

    chmod +x /bin/*-wrapper.sh
    chmod +x /bin/set_spam_acl.sh

    cat > /etc/supervisord.conf << EOF
[supervisord]
nodaemon=true

[program:rsyslog]
command=/bin/rsyslog-wrapper.sh 
[program:httpd]
command=/bin/httpd-wrapper.sh 
;[program:nginx]
;command=/bin/nginx-wrapper.sh 
;[program:php-fpm]
;command=/bin/php-fpm-wrapper.sh 
[program:mysqld]
command=/bin/mysqld-wrapper.sh 
[program:dirsrv]
command=/bin/dirsrv-wrapper.sh 
[program:postfix]
command=/bin/postfix-wrapper.sh 
[program:cyrus-imapd]
command=/bin/cyrus-imapd-wrapper.sh 
[program:amavisd]
command=/bin/amavisd-wrapper.sh 
[program:clamd]
command=/bin/clamd-wrapper.sh 
[program:wallace]
command=/bin/wallace-wrapper.sh 
[program:kolabd]
command=/bin/kolabd-wrapper.sh 
[program:kolab-saslauthd]
command=/bin/kolab-saslauthd-wrapper.sh 
;[program:opendkim]
;command=/bin/opendkim-wrapper.sh 
;[program:fail2ban]
;command=/bin/fail2ban-wrapper.sh 
;[program:set_spam_acl]
;command=/bin/set_spam_acl.sh 
EOF

    echo "info:  finished configuring Supervisor"
}

configure_kolab()
{
    if [ ! -d /etc/dirsrv/slapd-* ] ; then 
        echo "info:  start configuring Kolab"
        adduser dirsrv
        expect <<EOF
spawn   setup-kolab --fqdn=$(hostname -f) --timezone=$kolab_Timezone_ID
set timeout 300
expect  "Administrator password *:"
send    "$kolab_Administrator_password\r"
expect  "Confirm Administrator password:"
send    "$kolab_Administrator_password\r"
expect  "Directory Manager password *:"
send    "$kolab_Directory_Manager_password\r"
expect  "Confirm Directory Manager password:"
send    "$kolab_Directory_Manager_password\r"
expect  "User *:"
send    "dirsrv\r"
expect  "Group *:"
send    "dirsrv\r"
expect  "Please confirm this is the appropriate domain name space"
send    "yes\r"
expect  "The standard root dn we composed for you follows"
send    "yes\r"
expect  "Cyrus Administrator password *:"
send    "$kolab_Cyrus_Administrator_password\r"
expect  "Confirm Cyrus Administrator password:"
send    "$kolab_Cyrus_Administrator_password\r"
expect  "Kolab Service password *:"
send    "$kolab_Kolab_Service_password\r"
expect  "Confirm Kolab Service password:"
send    "$kolab_Kolab_Service_password\r"
expect  "What MySQL server are we setting up"
send    "2\r"
expect  "MySQL root password *:"
send    "$kolab_MySQL_root_password\r"
expect  "Confirm MySQL root password:"
send    "$kolab_MySQL_root_password\r"
expect  "MySQL kolab password *:"
send    "$kolab_MySQL_kolab_password\r"
expect  "Confirm MySQL kolab password:"
send    "$kolab_MySQL_kolab_password\r"
expect  "MySQL roundcube password *:"
send    "$kolab_MySQL_roundcube_password\r"
expect  "Confirm MySQL roundcube password:"
send    "$kolab_MySQL_roundcube_password\r"
expect  "Starting kolabd:"
exit    0
EOF

        # fix bug: "unable to open Berkeley db /etc/sasldb2: No such file or directory"
        echo password | saslpasswd2 sasldb2 && chown cyrus:saslauth /etc/sasldb2
    
        # SSL by default in apache
        sed -i -e 's/<Directory \/>/<Directory \/>\n    RedirectMatch \^\/$ \/webmail\//g' /etc/httpd/conf/httpd.conf

        echo "info:  finished configuring Kolab"
    else
        echo "warn: Kolab already configured, skipping..."
    fi
}

configure_nginx()
{
    if [[ $(grep -c Kolab /etc/nginx/conf.d/default.conf) == 0 ]] ; then
        echo "info:  start configuring nginx"

        # This section is made using the official kolab wiki-page:
        # https://docs.kolab.org/howtos/nginx-webserver.html

        rm -f /etc/php-fpm.d/www.conf

        cat > /etc/php-fpm.d/kolab_chwala.conf << EOF
[kolab_chwala]
user = apache
group = apache
listen = /var/run/php-fpm/kolab_chwala.sock
pm = dynamic
pm.max_children = 40
pm.start_servers = 15
pm.min_spare_servers = 10
pm.max_spare_servers = 20
chdir = /
php_value[upload_max_filesize] = 30M
php_value[post_max_size] = 30M
EOF
        cat > /etc/php-fpm.d/kolab_iRony.conf << EOF
[kolab_iRony]
user = apache
group = apache
listen = /var/run/php-fpm/kolab_iRony.sock
pm = dynamic
pm.max_children = 40
pm.start_servers = 15
pm.min_spare_servers = 10
pm.max_spare_servers = 20
chdir = /
php_value[upload_max_filesize] = 30M
php_value[post_max_size] = 30M
EOF
        cat > /etc/php-fpm.d/kolab_kolab-freebusy.conf << EOF
[kolab_kolab-freebusy]
user = apache
group = apache
listen = /var/run/php-fpm/kolab_kolab-freebusy.sock
pm = dynamic
pm.max_children = 40
pm.start_servers = 15
pm.min_spare_servers = 10
pm.max_spare_servers = 20
chdir = /
EOF
        cat > /etc/php-fpm.d/kolab_kolab-syncroton.conf << EOF
[kolab_kolab-syncroton]
user = apache
group = apache
listen = /var/run/php-fpm/kolab_kolab-syncroton.sock
pm = dynamic
pm.max_children = 40
pm.start_servers = 15
pm.min_spare_servers = 10
pm.max_spare_servers = 20
chdir = /
php_flag[suhosin.session.encrypt] = Off
EOF
        cat > /etc/php-fpm.d/kolab_kolab-webadmin.conf << EOF
[kolab_kolab-webadmin]
user = apache
group = apache
listen = /var/run/php-fpm/kolab_kolab-webadmin.sock
pm = dynamic
pm.max_children = 40
pm.start_servers = 15
pm.min_spare_servers = 10
pm.max_spare_servers = 20
chdir = /
EOF
        cat > /etc/php-fpm.d/kolab_roundcubemail.conf << EOF
[roundcubemail]
user = apache
group = apache
listen = /var/run/php-fpm/kolab_roundcubemail.sock
pm = dynamic
pm.max_children = 40
pm.start_servers = 15
pm.min_spare_servers = 10
pm.max_spare_servers = 20
chdir = /
# Derived from .htaccess of roundcube
php_flag[display_errors] = Off
php_flag[log_errors] = On

php_value[upload_max_filesize] = 30M
php_value[post_max_size] = 30M

php_flag[zlib.output_compression] = Off
php_flag[magic_quotes_gpc] = Off
php_flag[magic_quotes_runtime] = Off
php_flag[zend.ze1_compatibility_mode] = Off
php_flag[suhosin.session.encrypt] = Off

php_flag[session.auto_start] = Off
php_value[session.gc_maxlifetime] = 21600
php_value[session.gc_divisor] = 500
php_value[session.gc_probability] = 1

# http://bugs.php.net/bug.php?id=30766
php_value[mbstring.func_overload] = 0
EOF

        cat > /etc/nginx/conf.d/default.conf << EOF
#
# Force HTTP Redirect
#
server {
    listen 80 default_server;
    server_name _;
    server_name_in_redirect off;
    rewrite ^ https://\$http_host\$request_uri permanent; # enforce https redirect
}

#
# Full Kolab Stack
#
server {
    listen 443 ssl default_server;
    server_name $(hostname -f);
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    # enable ssl

    ssl on;
    ssl_certificate /etc/pki/tls/private/localhost.pem;
    ssl_certificate_key /etc/pki/tls/private/localhost.pem;

    # Start common Kolab config

    ##
    ## Chwala
    ##
    location /chwala {
        index index.php;
        alias /usr/share/chwala/public_html;

        client_max_body_size 30M; # set maximum upload size

        # enable php
        location ~ .php$ {
            include fastcgi_params;
            fastcgi_param HTTPS on;
            fastcgi_pass unix:/var/run/php-fpm/kolab_chwala.sock;
            fastcgi_param SCRIPT_FILENAME \$request_filename;
            # Without this, PHPSESSION is replaced by webadmin-api X-Session-Token
            fastcgi_param PHP_VALUE "session.auto_start=0
                session.use_cookies=0";
            fastcgi_pass_header X-Session-Token;
        }
    }

    ##
    ## iRony
    ##
    location /iRony {
        alias  /usr/share/iRony/public_html/index.php;

        client_max_body_size 30M; # set maximum upload size

        # If Nginx was built with http_dav_module:
        dav_methods  PUT DELETE MKCOL COPY MOVE;
        # Required Nginx to be built with nginx-dav-ext-module:
        # dav_ext_methods PROPFIND OPTIONS;

        include fastcgi_params;
        # fastcgi_param DAVBROWSER 1;
        fastcgi_param HTTPS on;
        fastcgi_index index.php;
        fastcgi_pass unix:/var/run/php-fpm/kolab_iRony.sock;
        fastcgi_param SCRIPT_FILENAME \$request_filename;
    }
    location ~* /.well-known/(cal|card)dav {
        rewrite ^ /iRony/ permanent;
    }

    ##
    ## Kolab Webclient
    ##
    location / {
        index index.php;
        root /usr/share/roundcubemail/public_html;

        # support for csrf token
        rewrite "^/[a-f0-9]{16}/(.*)" /\$1 break;

        # maximum upload size for mail attachments
        client_max_body_size 30M;

        # enable php
        location ~ .php$ {
            include fastcgi_params;
            fastcgi_param HTTPS on;
            fastcgi_split_path_info ^(.+.php)(/.*)$;
            fastcgi_pass unix:/var/run/php-fpm/kolab_roundcubemail.sock;
            fastcgi_param SCRIPT_FILENAME \$request_filename;
        }
    }

    ##
    ## Kolab Web Administration Panel (WAP) and API
    ##
    location /kolab-webadmin {
        index index.php;
        alias /usr/share/kolab-webadmin/public_html;
        try_files \$uri \$uri/ @kolab-wapapi;

        # enable php
        location ~ .php$ {
            include fastcgi_params;
            fastcgi_param HTTPS on;
            fastcgi_pass unix:/var/run/php-fpm/kolab_kolab-webadmin.sock;
            fastcgi_param SCRIPT_FILENAME \$request_filename;
            # Without this, PHPSESSION is replaced by webadmin-api X-Session-Token
            fastcgi_param PHP_VALUE "session.auto_start=0
                session.use_cookies=0";
            fastcgi_pass_header X-Session-Token;
        }
    }
    # kolab-webadmin api
    location @kolab-wapapi {
        rewrite ^/kolab-webadmin/api/([^.]*).([^.]*)$ /kolab-webadmin/api/index.php?service=\$1&method=\$2;
    }

    ##
    ## Kolab syncroton ActiveSync
    ##
    location /Microsoft-Server-ActiveSync {
        alias  /usr/share/kolab-syncroton/index.php;

        client_max_body_size 30M; # maximum upload size for mail attachments

        include fastcgi_params;
        fastcgi_param HTTPS on;
        fastcgi_read_timeout 1200;
        fastcgi_index index.php;
        fastcgi_pass unix:/var/run/php-fpm/kolab_kolab-syncroton.sock;
        fastcgi_param SCRIPT_FILENAME /usr/share/kolab-syncroton/index.php;
    }

    ##
    ## Kolab Free/Busy
    ##
    location /freebusy {
        alias  /usr/share/kolab-freebusy/public_html/index.php;

        include fastcgi_params;
        fastcgi_param HTTPS on;
        fastcgi_index index.php;
        fastcgi_pass unix:/var/run/php-fpm/kolab_kolab-freebusy.sock;
        fastcgi_param SCRIPT_FILENAME /usr/share/kolab-freebusy/public_html/index.php;
    }
    # End common Kolab config
}
EOF

        sed -i '/^\[kolab_wap\]/,/^\[/ { x; /^$/ !{ x; H }; /^$/ { x; h; }; d; }; x; /^\[kolab_wap\]/ { s/\(\n\+[^\n]*\)$/\napi_url = https:\/\/'$(hostname -f)'\/kolab-webadmin\/api\1/; p; x; p; x; d }; x' /etc/kolab/kolab.conf

        sed -i "s/\$config\['assets_path'\] = '.*';/\$config\['assets_path'\] = '\/assets\/';/g" /etc/roundcubemail/config.inc.php

        # Comment apache
        sed -i '/^[^;]*httpd/s/^/;/' /etc/supervisord.conf
        # Uncoment nginx and php-fpm
        sed -i '/^;.*nginx/s/^;//' /etc/supervisord.conf
        sed -i '/^;.*php-fpm/s/^;//' /etc/supervisord.conf

        echo "info:  finished configuring nginx"
    else
        echo "warn:  nginx already configured, skipping..."
    fi
}

configure_nginx_cache()
{
    if [[ $(grep -c open_file_cache /etc/nginx/nginx.conf) == 0 ]] ; then
        echo "info:  start configuring nginx cacheing"

        #Adding open file cache to nginx
        sed -i '/include \/etc\/nginx\/conf\.d\/\*.conf;/{
        N
        a \    open_file_cache max=16384 inactive=5m;
        a \    open_file_cache_valid 90s; 
        a \    open_file_cache_min_uses 2;
        a \    open_file_cache_errors on;
        }' /etc/nginx/nginx.conf


        #Adding fastcgi_cache to nginx
        mkdir -p /var/lib/nginx/fastcgi/
        chown -R nginx:nginx /var/lib/nginx/fastcgi/
        chmod -R 700 /var/lib/nginx/fastcgi/

        sed -i '/include \/etc\/nginx\/conf\.d\/\*.conf;/{
        N
        a \    fastcgi_cache_key "$scheme$request_method$host$request_uri";
        a \    fastcgi_cache_use_stale error timeout invalid_header http_500;
        a \    fastcgi_cache_valid 200 302 304 10m;
        a \    fastcgi_cache_valid 301 1h; 
        a \    fastcgi_cache_min_uses 2; 
        }' /etc/nginx/nginx.conf

        sed -i '1ifastcgi_cache_path /var/lib/nginx/fastcgi/ levels=1:2 keys_zone=key-zone-name:16m max_size=256m inactive=1d;' /etc/nginx/conf.d/default.conf

        sed -i '/ssl_certificate_key/a \    fastcgi_cache key-zone-name;' /etc/nginx/conf.d/default.conf

        echo "info:  finished configuring nginx caching"
    else
        echo "warn:  nginx cacheing already configured, skipping..."
    fi
}

configure_amavis()
{
    if [[ $(grep -c \$final_spam_destiny.*D_PASS /etc/amavisd/amavisd.conf) == 0 ]] ; then
        echo "info:  start configuring amavis"
        
        sed -i '/^[^#]*$sa_spam_subject_tag/s/^/#/' /etc/amavisd/amavisd.conf
        sed -i '/^# $recipient_delimiter/s/^# //' /etc/amavisd/amavisd.conf
        sed -i 's/^\($final_spam_destiny.*= \).*/\1D_PASS;/' /etc/amavisd/amavisd.conf
    
        # Uncoment set_spam_acl
        sed -i '/^;.*set_spam_acl/s/^;//' /etc/supervisord.conf

        echo "info:  finished configuring amavis"
    else
        echo "warn:  amavis already configured, skipping..."
    fi
}

configure_ssl()
{
    if [ -f /etc/pki/tls/certs/domain.crt ] ; then
        echo "warn:  SSL already configured, but that's nothing wrong, run again..."
    fi
    echo "info:  start configuring SSL"
    cat > /tmp/update_ssl_key_message.txt << EOF


# Please paste here your SSL ___PRIVATE KEY___. Lines starting
# with '#' will be ignored, and an empty message aborts
# updating SSL-certificates procedure.
EOF
    cat > /tmp/update_ssl_crt_message.txt << EOF


# Please paste here your SSL ___CERTIFICATE___. Lines starting
# with '#' will be ignored, and an empty message aborts
# updating SSL-certificates procedure.
EOF

    cat > /tmp/update_ssl_ca_message.txt << EOF


# Please paste here your SSL ___CA-CERTIFICATE___. Lines starting
# with '#' will be ignored, and an empty message aborts
# updating SSL-certificates procedure.
EOF

    if [ -f /etc/pki/tls/private/domain.key ] ; then
	cat /etc/pki/tls/private/domain.key /tmp/update_ssl_key_message.txt > /tmp/update_ssl_domain.key
    else
	cat /tmp/update_ssl_key_message.txt > /tmp/update_ssl_domain.key
    fi

    if [ -f /etc/pki/tls/certs/domain.crt ] ; then
	cat /etc/pki/tls/certs/domain.crt /tmp/update_ssl_crt_message.txt > /tmp/update_ssl_domain.crt
    else
	cat /tmp/update_ssl_crt_message.txt > /tmp/update_ssl_domain.crt
    fi
    if [ -f /etc/pki/tls/certs/ca.pem ] ; then
	cat /etc/pki/tls/certs/ca.pem /tmp/update_ssl_ca_message.txt > /tmp/update_ssl_ca.pem
    else
	cat /tmp/update_ssl_ca_message.txt > /tmp/update_ssl_ca.pem
    fi

    vi /tmp/update_ssl_domain.key
    vi /tmp/update_ssl_domain.crt
    vi /tmp/update_ssl_ca.pem

    if [ "$(grep -c -v -E "^#|^$" /tmp/update_ssl_domain.key)" != "0" ] || [ "$(grep -c -v -E "^#|^$" /tmp/update_ssl_domain.crt)" != "0" ] || [ "$(grep -c -v -E "^#|^$" /tmp/update_ssl_ca.pem)" != "0" ] ; then
        grep -v -E "^#|^$" /tmp/update_ssl_domain.key > /etc/pki/tls/private/domain.key
        grep -v -E "^#|^$" /tmp/update_ssl_domain.crt > /etc/pki/tls/certs/domain.crt
        grep -v -E "^#|^$" /tmp/update_ssl_ca.pem > /etc/pki/tls/certs/ca.pem

        # Create certificate bundles
        cat /etc/pki/tls/certs/domain.crt /etc/pki/tls/private/domain.key /etc/pki/tls/certs/ca.pem > /etc/pki/tls/private/domain.bundle.pem
        cat /etc/pki/tls/certs/domain.crt /etc/pki/tls/certs/ca.pem > /etc/pki/tls/certs/domain.bundle.pem
        cat /etc/pki/tls/certs/ca.pem > /etc/pki/tls/certs/domain.ca-chain.pem
        # Set access rights
        chown -R root:mail /etc/pki/tls/private
        chmod 600 /etc/pki/tls/private/domain.key
        chmod 750 /etc/pki/tls/private
        chmod 640 /etc/pki/tls/private/*
        # Add CA to system’s CA bundle
        cat /etc/pki/tls/certs/ca.pem >> /etc/pki/tls/certs/ca-bundle.crt

        # Configure apache for SSL

        # Set your ssl certificates 
        sed -i -e '/SSLCertificateFile \/etc\/pki/c\SSLCertificateFile /etc/pki/tls/certs/domain.crt' /etc/httpd/conf.d/ssl.conf
        sed -i -e '/SSLCertificateKeyFile \/etc\/pki/c\SSLCertificateKeyFile /etc/pki/tls/private/domain.key' /etc/httpd/conf.d/ssl.conf
        sed -i -e '/SSLCertificateChainFile \/etc\/pki/c\SSLCertificateChainFile /etc/pki/tls/certs/domain.ca-chain.pem' /etc/httpd/conf.d/ssl.conf
            
        # Create a vhost for http (:80) to redirect everything to https
        cat >> /etc/httpd/conf/httpd.conf << EOF

<VirtualHost _default_:80>
    RewriteEngine On
    RewriteRule ^(.*)$ https://%{HTTP_HOST}$1 [R=301,L]
</VirtualHost>
EOF

        # Configuration nginx for SSL
        sed -i -e '/    ssl_certificate \/etc\/pki/c\    ssl_certificate /etc/pki/tls/certs/domain.bundle.pem;' /etc/nginx/conf.d/default.conf
        sed -i -e '/    ssl_certificate_key \/etc\/pki/c\    ssl_certificate_key /etc/pki/tls/private/domain.key;' /etc/nginx/conf.d/default.conf
    
        #Configure Cyrus for SSL
        sed -r -i \
            -e 's|^tls_server_cert:.*|tls_server_cert: /etc/pki/tls/certs/domain.crt|g' \
            -e 's|^tls_server_key:.*|tls_server_key: /etc/pki/tls/private/domain.key|g' \
            -e 's|^tls_server_ca_file:.*|tls_server_ca_file: /etc/pki/tls/certs/domain.ca-chain.pem|g' \
            /etc/imapd.conf
    
        #Configure Postfix for SSL
        postconf -e smtpd_tls_key_file=/etc/pki/tls/private/domain.key
        postconf -e smtpd_tls_cert_file=/etc/pki/tls/certs/domain.crt
        postconf -e smtpd_tls_CAfile=/etc/pki/tls/certs/domain.ca-chain.pem
    
        #Configure kolab-cli for SSL
        sed -r -i \
              -e '/api_url/d' \
              -e "s#\[kolab_wap\]#[kolab_wap]\napi_url = https://$(hostname -f)/kolab-webadmin/api#g" \
              /etc/kolab/kolab.conf
    
        #Configure Roundcube for SSL
        sed -i -e 's/http:/https:/' /etc/roundcubemail/libkolab.inc.php
        sed -i -e 's/http:/https:/' /etc/roundcubemail/kolab_files.inc.php
        sed -i -e '/^?>/d' /etc/roundcubemail/config.inc.php
        
        # Tell the webclient the SSL iRony URLs for CalDAV and CardDAV
        cat >> /etc/roundcubemail/config.inc.php << EOF
# caldav/webdav
\$config['calendar_caldav_url']             = "https://%h/iRony/calendars/%u/%i";
\$config['kolab_addressbook_carddav_url']   = 'https://%h/iRony/addressbooks/%u/%i';
EOF

        # Redirect all http traffic to https
        cat >> /etc/roundcubemail/config.inc.php << EOF
# Force https redirect for http requests
\$config['force_https'] = true;
EOF

    else 
        echo "error: input of certifacte or private key or ca-sertificate is blank, skipping..."
    fi

    rm -rf /tmp/update_ssl*
    echo "info:  finished configuring SSL"
}

configure_fail2ban()
{
    if [ "$(grep -c "kolab" /etc/fail2ban/jail.conf)" == "0" ] ; then
        echo "info:  start configuring Fail2ban"

        cat > /etc/fail2ban/filter.d/kolab-cyrus.conf << EOF
[Definition]
failregex = (imaps|pop3s)\[[0-9]*\]: badlogin: \[<HOST>\] (plain|PLAIN|login|plaintext) .*
ignoreregex =
EOF
        cat > /etc/fail2ban/filter.d/kolab-postfix.conf << EOF
[Definition]
failregex = postfix\/submission\/smtpd\[[0-9]*\]: warning: unknown\[<HOST>\]: SASL (PLAIN|LOGIN) authentication failed: authentication failure
ignoreregex =
EOF
        cat > /etc/fail2ban/filter.d/kolab-roundcube.conf << EOF
[Definition]
failregex = <.*> Failed login for .* from <HOST> in session .*
ignoreregex =
EOF
        cat > /etc/fail2ban/filter.d/kolab-irony.conf << EOF
[Definition]
failregex = <.*> Failed login for .* from <HOST> in session .*
ignoreregex =
EOF
        cat > /etc/fail2ban/filter.d/kolab-chwala.conf << EOF
[Definition]
failregex = <.*> Failed login for .* from <HOST> in session .*
ignoreregex =
EOF
        cat > /etc/fail2ban/filter.d/kolab-syncroton.conf << EOF
[Definition]
failregex = <.*> Failed login for .* from <HOST> in session .*
ignoreregex =
EOF
        if [ "$(grep -c "kolab" /etc/fail2ban/jail.conf)" == "0" ] ; then
            cat >> /etc/fail2ban/jail.conf << EOF

[kolab-cyrus]

enabled = true
filter  = kolab-cyrus
action  = iptables-multiport[name=cyrus-imap,port="143,993,110,995,4190"]
logpath = /var/log/maillog
maxretry = 5

[kolab-postfix]

enabled = true
filter  = kolab-postfix
action  = iptables-multiport[name=kolab-postfix,port="25,587"]
logpath = /var/log/maillog
maxretry = 5

[kolab-roundcube]

enabled = true
filter  = kolab-roundcube
action  = iptables-multiport[name=kolab-roundcube, port="http,https"]
logpath = /var/log/roundcubemail/userlogins
maxretry = 5

[kolab-irony]

enabled = true
filter  = kolab-irony
action  = iptables-multiport[name=kolab-irony,port="http,https"]
logpath = /var/log/iRony/userlogins
maxretry = 5

[kolab-chwala]

enabled = true
filter  = kolab-chwala
action  = iptables-multiport[name=kolab-chwala,port="http,https"]
logpath = /var/log/chwala/userlogins
maxretry = 5

[kolab-syncroton]

enabled = true
filter  = kolab-syncroton
action  = iptables-multiport[name=kolab-syncroton,port="http,https"]
logpath = /var/log/kolab-syncroton/userlogins
maxretry = 5
EOF

        fi

        # Uncoment fail2ban
        sed -i '/^;.*fail2ban/s/^;//' /etc/supervisord.conf

        echo "info:  finished configuring Fail2ban"
    else
        echo "warn:  Fail2ban already configured, skipping..."
    fi
}

configure_dkim()
{
    if [ "$(grep -c -ve "^#\|^[[:space:]]*$"  /etc/opendkim/KeyTable )" == "0" ] ; then
        echo "info:  start configuring OpenDKIM"

        opendkim-genkey -D /etc/opendkim/keys/ -d $(hostname -d) -s $(hostname -s)
        
        chgrp opendkim /etc/opendkim/keys/*
        chmod g+r /etc/opendkim/keys/*
    
            sed -i "/^127\.0\.0\.1\:[10025|10027].*smtpd/a \    -o receive_override_options=no_milters" /etc/postfix/master.cf
    
        sed -i 's/^\(^Mode\).*/\1  sv/' /etc/opendkim.conf

        tee -a /etc/opendkim.conf  <<EOF
KeyTable      /etc/opendkim/KeyTable
SigningTable  /etc/opendkim/SigningTable
X-Header yes 
EOF

        echo $(hostname -f | sed s/\\./._domainkey./) $(hostname -d):$(hostname -s):$(ls /etc/opendkim/keys/*.private) | tee -a /etc/opendkim/KeyTable
        echo $(hostname -d) $(echo $(hostname -f) | sed s/\\./._domainkey./) | tee -a /etc/opendkim/SigningTable

        postconf -e milter_default_action=accept
        postconf -e milter_protocol=2
        postconf -e smtpd_milters=inet:localhost:8891
        postconf -e non_smtpd_milters=inet:localhost:8891
    
        # Uncoment opendkim
        sed -i '/^;.*opendkim/s/^;//' /etc/supervisord.conf

        echo "info:  finished configuring OpenDKIM"
    else
        echo "warn:  OpenDKIM already configured, skipping..."
    fi
}

configure_larry_skin()
{
    if [ "$(grep -c "larry" /etc/roundcubemail/config.inc.php)" == "0" ] ; then
        echo "info:  start configuring Larry skin as default"

        sed -i "s/\$config\['skin'\] = '.*';/\$config\['skin'\] = 'larry';/g" /etc/roundcubemail/config.inc.php

        echo "info:  finished configuring Larry skin as default"
    else
        echo "warn:  Larry skin already configured as default, skipping..."
    fi
}

configure_zipdownload()
{
    if [ "$(grep -c "zipdownload" /etc/roundcubemail/config.inc.php)" == "0" ] ; then
        echo "info:  start configuring zipdownload plugin"

        git clone https://github.com/roundcube/roundcubemail/ --depth 1 /tmp/roundcube
        mv /tmp/roundcube/plugins/zipdownload/ /usr/share/roundcubemail/plugins/
        rm -rf /tmp/roundcube/
        sed -i "/'contextmenu',/a \            'zipdownload'," /etc/roundcubemail/config.inc.php

        echo "info:  finished configuring zipdownload plugin"
    else
        echo "warn:  zipdownload plugin already configured, skipping..."
    fi
}

print_passwords()
{
    echo "======================================================="
    echo "Please save your passwords:                            "
    echo "======================================================="
    cat /etc/settings.ini | grep password
    echo
    echo "            (You can also see it in /etc/settings.ini)"
    echo "_______________________________________________________"
}

print_dkim_keys()
{
    echo "_______________________________________________________"
    echo
    echo "Your DNS-record for your DKIM key:"
    echo
    cat /etc/opendkim/keys/$(hostname -s).txt
    echo "_______________________________________________________"
}

if [ "$1" = "--help" ] || [ "$1" = "-h" ] || [ "$1" = "help" ] ; then 
    usage
fi

mount_dirs

if [ ! -d /etc/dirsrv/slapd-* ] ; then 
    echo "info:  First installation detected, run setup wizard..."

    vi /etc/settings.ini
    get_config /etc/settings.ini
    fix_fdirs
    configure_supervisor
    # Main
    if [ $main_configure_kolab = "true" ] ; then configure_kolab ; fi
    if [ $main_configure_nginx = "true" ] ; then configure_nginx ; fi
    if [ $main_configure_nginx_cache = "true" ] ; then configure_nginx_cache ; fi
    if [ $main_configure_amavis = "true" ] ; then configure_amavis ; fi
    if [ $main_configure_ssl = "true" ] ; then configure_ssl ; fi
    if [ $main_configure_fail2ban = "true" ] ; then configure_fail2ban ; fi
    if [ $main_configure_dkim = "true" ] ; then configure_dkim ; fi
    # Extras
    if [ $extras_configure_larry_skin = "true" ] ; then configure_larry_skin ; fi
    if [ $extras_configure_zipdownload = "true" ] ; then configure_zipdownload ; fi
    # Print parameters
    if [ $main_configure_kolab = "true" ] ; then print_passwords ; fi
    if [ $main_configure_dkim = "true" ] ; then print_dkim_keys ; fi

else
    echo "info:  Kolab already installed, run services..."
    /usr/bin/supervisord
fi


if [ "${#1}" -ge "1" ] ; then

    get_config /etc/settings.ini
    # Main
    if [ "$1" == "kolab" ] ; then configure_kolab ; print_passwords ; fi
    if [ "$1" == "nginx" ] ; then configure_nginx ; fi
    if [ "$1" == "nginx_cache" ] ; then configure_nginx_cache ; fi
    if [ "$1" == "amavis" ] ; then configure_amavis ; fi
    if [ "$1" == "ssl" ] ; then configure_ssl ; fi
    if [ "$1" == "fail2ban" ] ; then configure_fail2ban ; fi
    if [ "$1" == "dkim" ] ; then configure_dkim ; print_dkim_keys ; fi
    # Extras
    if [ "$1" == "larry" ] ; then configure_larry_skin ; fi
    if [ "$1" == "zipdownload" ] ; then configure_zipdownload ; fi
    # Print parameters
    if [ "$1" = "kolab" ] ; then print_passwords ; fi
    if [ "$1" = "dkim" ] ; then print_dkim_keys ; fi

fi
