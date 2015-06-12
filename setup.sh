#!/bin/bash
usage ()
{
     echo
     echo "Usage:    ./setup.sh [ARGUMENT]"
     echo
     echo "Arguments:"
     echo "    kolab                 - Configure Kolab"
     echo "    nginx                 - Configure nginx"
     echo "    amavis                - Configure amavis"
     echo "    ssl                   - Configure SSL using your certs"
     echo "    fail2ban              - Configure Fail2ban"
     echo "    opendkim              - Configure OpenDKIM"
     echo "    zipdownload           - Configure zipdownload plugin for roundcube"
     echo "    zlib	             - Update php-zlib"
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

    new_hostname="$(echo $main_hostname | cut -d. -f1)"
    new_domain="$(echo $main_hostname | cut -d. -f2-)"

}
set_hostname()
{
    old_hostname="$(cat /etc/hosts | awk 'NR == 1{print $2}')"
    echo $main_hostname > /etc/hostname
    sed -e "s/$old_hostname.*$/$main_hostname\ $new_hostname/g" /etc/hosts | tee /etc/hosts
}

configure_supervisor()
{
    mkdir -p /root/wrappers/

    cat > /root/wrappers/rsyslog.sh << EOF
#!/bin/bash
d=rsyslog
l=/var/log/messages
g=rsyslogd:
trap '{ service \$d stop; exit 0; }' EXIT 
service \$d start 
tail -f -n 1 \$l | grep \$g
EOF

    cat > /root/wrappers/nginx.sh << EOF
#!/bin/bash
d=nginx
l=/var/log/nginx/error.log
trap '{ service \$d stop; exit 0; }' EXIT 
service \$d start 
tail -f -n1 \$l
EOF

    cat > /root/wrappers/httpd.sh << EOF
#!/bin/bash
d=httpd
l=/var/log/httpd/error_log
trap '{ service \$d stop; exit 0; }' EXIT
service \$d start ; tail -f -n1 \$l
EOF

    cat > /root/wrappers/php-fpm.sh << EOF
#!/bin/bash
d=php-fpm
l=/var/log/php-fpm/error.log
trap '{ service \$d stop; exit 0; }' EXIT
service \$d start
tail -f -n1 \$l
EOF

    cat > /root/wrappers/mysqld.sh << EOF
#!/bin/bash
d=mysqld
l=/var/log/mysqld.log
trap '{ service \$d stop; exit 0; }' EXIT
service \$d start
tail -f -n1 \$l
EOF

    cat > /root/wrappers/dirsrv.sh << EOF
#!/bin/bash
d=dirsrv
l=/var/log/dirsrv/slapd-*/errors
trap '{ service \$d stop; exit 0; }' EXIT
service \$d start
tail -f -n1 \$l
EOF

    cat > /root/wrappers/postfix.sh << EOF
#!/bin/bash
d=postfix
l=/var/log/maillog
g='postfix.*\[.*\]:'
trap '{ service \$d stop; exit 0; }' EXIT
service \$d start
tail -f -n1 \$l | grep \$g
EOF

    cat > /root/wrappers/cyrus-imapd.sh << EOF
#!/bin/bash
d=cyrus-imapd
l=/var/log/maillog
g='[master\|pop3\|imap].*\[.*\]:'
trap '{ service \$d stop; exit 0; }' EXIT 
service \$d start
tail -f -n1 \$l
EOF

    cat > /root/wrappers/amavisd.sh << EOF
#!/bin/bash
d=amavisd
l=/var/log/maillog
g='amavis.*\[.*\]:'
trap '{ service \$d stop; exit 0; }' EXIT
service \$d start
tail -f -n1 \$l | grep \$g
EOF

    cat > /root/wrappers/clamd.sh << EOF
#!/bin/bash
d=clamd
l=/var/log/clamav/clamd.log
trap '{ service \$d stop; exit 0; }' EXIT
service \$d start 
tail -f -n1 \$l
EOF

    cat > /root/wrappers/wallace.sh << EOF
#!/bin/bash
d=wallace
trap '{ service \$d stop; exit 0; }' EXIT
service \$d start
sleep infinity
EOF

    cat > /root/wrappers/kolabd.sh << EOF
#!/bin/bash
d=kolabd
l=/var/log/kolab/pykolab.log
trap '{ service \$d stop; exit 0; }' EXIT 
sleep 10
service \$d start 
tail -f -n1 \$l
EOF

    cat > /root/wrappers/kolab-saslauthd.sh << EOF
#!/bin/bash
d=kolab-saslauthd
trap '{ sleep 2; service \$d stop; exit 0; }' EXIT
service \$d start
sleep infinity
EOF

    cat > /root/wrappers/opendkim.sh << EOF
#!/bin/bash
d=opendkim
l=/var/log/maillog
g='opendkim.*\[.*\]:'
trap '{ service \$d stop; exit 0; }' EXIT
service \$d start
tail -f -n1 \$l | grep \$g
EOF

    cat > /root/wrappers/fail2ban.sh << EOF
#!/bin/bash
d=fail2ban
l=/var/log/messages
g='fail2ban.*\[.*\]:'
trap '{ service \$d stop; exit 0; }' EXIT
service \$d start
tail -f -n1 \$l | grep \$g
EOF

    cat > /root/wrappers/set_spam_acl.sh << EOF 
#!/bin/bash
set_spam_acl ()
{
    kolab sam user/%/Spam@$new_domain anyone p
    sleep 15m 
    set_spam_acl
}
set_spam_acl
EOF


    chmod +x wrappers/*

    cat > /etc/supervisord.conf << EOF
[supervisord]
nodaemon=true

[program:rsyslog]
command=/root/wrappers/rsyslog.sh 
[program:httpd]
command=/root/wrappers/httpd.sh 
;[program:nginx]
;command=/root/wrappers/nginx.sh 
;[program:php-fpm]
;command=/root/wrappers/php-fpm.sh 
[program:mysqld]
command=/root/wrappers/mysqld.sh 
[program:dirsrv]
command=/root/wrappers/dirsrv.sh 
[program:postfix]
command=/root/wrappers/postfix.sh 
[program:cyrus-imapd]
command=/root/wrappers/cyrus-imapd.sh 
[program:amavisd]
command=/root/wrappers/amavisd.sh 
[program:clamd]
command=/root/wrappers/clamd.sh 
[program:wallace]
command=/root/wrappers/wallace.sh 
[program:kolabd]
command=/root/wrappers/kolabd.sh 
[program:kolab-saslauthd]
command=/root/wrappers/kolab-saslauthd.sh 
;[program:opendkim]
;command=/root/wrappers/opendkim.sh 
;[program:fail2ban]
;command=/root/wrappers/fail2ban.sh 
;[program:set_spam_acl]
;command=/root/wrappers/set_spam_acl.sh 
EOF
}

configure_kolab()
{
    set_hostname
    adduser dirsrv
    expect <<EOF
spawn   setup-kolab --fqdn=$main_hostname --timezone=$kolab_Timezone_ID
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

}

configure_nginx() {
    # This section is made using the official kolab wiki-page:
    # https://docs.kolab.org/howtos/nginx-webserver.html

    service httpd stop
    #chkconfig httpd off

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
    server_name $main_hostname;
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

    sed -i '/^\[kolab_wap\]/,/^\[/ { x; /^$/ !{ x; H }; /^$/ { x; h; }; d; }; x; /^\[kolab_wap\]/ { s/\(\n\+[^\n]*\)$/\napi_url = https:\/\/'$main_hostname'\/kolab-webadmin\/api\1/; p; x; p; x; d }; x' /etc/kolab/kolab.conf

    sed -i "s/\$config\['assets_path'\] = '.*';/\$config\['assets_path'\] = '\/assets\/';/g" /etc/roundcubemail/config.inc.php

    service php-fpm start
    #chkconfig php-fpm on
    service nginx start
    #chkconfig nginx on

    # Comment apache
    sed -i '/^[^;]*httpd/s/^/;/' /etc/supervisord.conf
    # Uncoment nginx and php-fpm
    sed -i '/^;.*nginx/s/^;//' /etc/supervisord.conf
    sed -i '/^;.*php-fpm/s/^;//' /etc/supervisord.conf

}

configure_amavis()
{
        
    sed -i '/^[^#]*$sa_spam_subject_tag/s/^/#/' /etc/amavisd/amavisd.conf
    sed -i '/^# $recipient_delimiter/s/^# //' /etc/amavisd/amavisd.conf
    sed -i 's/^\($final_spam_destiny.*= \).*/\1D_PASS;/' /etc/amavisd/amavisd.conf
    
    # Uncoment set_spam_acl
    sed -i '/^;.*set_spam_acl/s/^;//' /etc/supervisord.conf

}

configure_ssl()
{

    if [[ ( -f /root/certs/domain.crt ) && ( -f /root/certs/domain.key ) && ( -f /root/certs/ca.pem ) ]]; then

        mv /root/certs/domain.key /etc/pki/tls/private/domain.key
        mv /root/certs/domain.crt /etc/pki/tls/certs/domain.crt
        mv /root/certs/ca.pem /etc/pki/tls/certs/ca.pem
        
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
        if [ "$(grep -c "webmail" /etc/httpd/conf/httpd.conf)" == "0" ] ; then sed -i -e 's/<Directory \/>/<Directory \/>\n    RedirectMatch \^\/$ \/webmail\//g' /etc/httpd/conf/httpd.conf; fi
        
        # Create a vhost for http (:80) to redirect everything to https
        cat >> /etc/httpd/conf/httpd.conf << EOF

<VirtualHost _default_:80>
    RewriteEngine On
    RewriteRule ^(.*)$ https://%{HTTP_HOST}$1 [R=301,L]
</VirtualHost>
EOF

        # Configuration nginx for SSL
        #
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e '/    ssl_certificate \/etc\/pki/c\    ssl_certificate /etc/pki/tls/certs/domain.bundle.pem;' /etc/nginx/conf.d/default.conf
            sed -i -e '/    ssl_certificate_key \/etc\/pki/c\    ssl_certificate_key /etc/pki/tls/private/domain.key;' /etc/nginx/conf.d/default.conf
        fi
    
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
              -e "s#\[kolab_wap\]#[kolab_wap]\napi_url = https://$main_hostname/kolab-webadmin/api#g" \
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
    echo "certs/domain.crt or certs/domain.key or certs/ca.pem not found, skipping..."
fi

}

configure_fail2ban()
{

touch /var/log/maillog
mkdir -p /var/log/roundcubemail && touch /var/log/roundcubemail/userlogins ; chown apache:apache -R /var/log/roundcubemail
mkdir -p /var/log/syncroton && touch /var/log/syncroton/userlogins ; chown apache:apache -R /var/log/syncroton
mkdir -p /var/log/chwala && touch /var/log/chwala/userlogins ; chown apache:apache -R /var/log/chwala
mkdir -p /var/log/iRony && touch /var/log/iRony/userlogins ; chown apache:apache -R /var/log/iRony


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
logpath = /var/log/syncroton/userlogins
maxretry = 5
EOF

    fi

    # Uncoment fail2ban
    sed -i '/^;.*fail2ban/s/^;//' /etc/supervisord.conf


}

configure_dkim()
{
    opendkim-genkey -D /etc/opendkim/keys/ -d $new_domain -s $new_hostname
    
    chgrp opendkim /etc/opendkim/keys/*
    chmod g+r /etc/opendkim/keys/*

    if [ "$(grep -c "no_milters" /etc/postfix/master.cf )" == "0" ] ; then 
        sed -i "/^127\.0\.0\.1\:[10025|10027].*smtpd/a \    -o receive_override_options=no_milters" /etc/postfix/master.cf
    fi

    sed -i 's/^\(^Mode\).*/\1  sv/' /etc/opendkim.conf

    if [ "$(grep -c "^KeyTable" /etc/opendkim.conf)" == "0" ] ; then
        tee -a /etc/opendkim.conf  <<EOF
KeyTable      /etc/opendkim/KeyTable
SigningTable  /etc/opendkim/SigningTable
X-Header yes 
EOF
    fi

    if [ "$(grep -c "$new_domain" /etc/opendkim/KeyTable)" == "0" ] ; then
        echo $(echo $main_hostname | sed s/\\./._domainkey./) $new_domain:$new_hostname:$(ls /etc/opendkim/keys/*.private) | tee -a /etc/opendkim/KeyTable
    fi

    if [ "$(grep -c "$new_domain" /etc/opendkim/SigningTable)" == "0" ] ; then
        echo $new_domain $(echo $main_hostname | sed s/\\./._domainkey./) | tee -a /etc/opendkim/SigningTable
    fi    

    postconf -e milter_default_action=accept
    postconf -e milter_protocol=2
    postconf -e smtpd_milters=inet:localhost:8891
    postconf -e non_smtpd_milters=inet:localhost:8891

    # Uncoment opendkim
    sed -i '/^;.*opendkim/s/^;//' /etc/supervisord.conf

}

configure_zipdownload()
{
    yum install -y git 
    git clone https://github.com/roundcube/roundcubemail/ --depth 1 /tmp/roundcube
    mv /tmp/roundcube/plugins/zipdownload/ /usr/share/roundcubemail/plugins/
    rm -rf /tmp/roundcube/
    if [ "$(grep -c "zipdownload" /etc/roundcubemail/config.inc.php)" == "0" ] ; then sed -i "/'contextmenu',/a \            'zipdownload'," /etc/roundcubemail/config.inc.php ; fi
}

configure_zlib()
{
    yum -y install php-devel zlib-devel gcc pcre-devel
    pecl install zip
    if [ "$(grep -c "extension=zip.so" /etc/php.ini)" == "0" ] ; then echo extension=zip.so >> /etc/php.ini ; fi
}

print_passwords()
{
    echo "======================================================="
    echo "Please save your passwords:                            "
    echo "======================================================="
    cat /root/settings.ini | grep password
    echo
    echo "            (You can also see it in /root/settings.ini)"
    echo "_______________________________________________________"
}

print_dkim_keys()
{
    echo "_______________________________________________________"
    echo
    echo "Your DNS-record for your DKIM key:"
    echo
    cat /etc/opendkim/keys/$new_hostname.txt
    echo "_______________________________________________________"
}




if [ "$1" = "--help" ] || [ "$1" = "-h" ] || [ "$1" = "help" ] ; then 
    usage
fi

get_config /root/settings.ini

configure_supervisor

# Main

if [[ $main_configure_kolab == "true" ]] || [ "$1" = "kolab" ] ; then
    configure_kolab
fi

if [[ $main_configure_nginx == "true" ]] || [ "$1" = "nginx" ] ; then
    configure_nginx
fi

if [[ $main_configure_amavis == "true" ]] || [ "$1" = "amavis" ] ; then
    configure_amavis
fi

if [[ $main_configure_ssl == "true" ]] || [ "$1" = "ssl" ] ; then
    configure_ssl
fi

if [[ $main_configure_fail2ban == "true" ]] || [ "$1" = "fail2ban" ] ; then
    configure_fail2ban
fi

if [[ $main_configure_dkim == "true" ]] || [ "$1" = "dkim" ] ; then
    configure_dkim
fi

# Extras

if [[ $extras_configure_zipdownload == "true" ]] || [ "$1" = "zipdownload" ] ; then
    configure_zipdownload
fi

if [[ $extras_configure_zlib == "zlib" ]] || [ "$1" = "zlib" ] ; then
    configure_zlib
fi

# Print functions

if [[ $main_configure_kolab == "true" ]] || [ "$1" = "kolab" ] ; then
    print_passwords
fi

if [[ $main_configure_dkim == "true" ]] || [ "$1" = "dkim" ] ; then
    print_dkim_keys
fi
