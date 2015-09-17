#!/bin/bash
usage ()
{
     echo
     echo "Usage:    ./setup.sh [ARGUMENT]"
     echo
     echo "Arguments:"
     echo "    run                   - Auto start all services or install wizard in case of initial setup"
     echo "    link                  - Create symlinks default folders to /data"
     echo "    kolab                 - Configure Kolab from config"
     echo "    amavis                - Configure amavis"
     echo "    nginx                 - Configure nginx"
     echo "    nginx_cache           - Configure nginx caching"
     echo "    ssl                   - Configure SSL using your certs"
     echo "    fail2ban              - Configure Fail2ban"
     echo "    dkim                  - Configure OpenDKIM"
     echo "    rcpt_off              - Disable the Recipient Policy"
     echo "    locale                - Configure default locale from config"
     echo "    size                  - Configure size from config"
     echo "    larry                 - Set Larry skin as default"
     echo "    zipdownload           - Configure zipdownload plugin for roundcube"
     echo "    trash                 - Configure trash folder istead flag for deletion"
     echo "    milter                - Configure another milter; disable amavis and clamd from config"
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
		sed -i --follow-symlinks "/\(^"$var"=\).*/ s//\1"$random_pwd"/ " $1	#save generated pass to settings.ini
            else
                eval $section"_"$var="$val"
            fi
        fi
    done < $1
    chmod 600 /etc/settings.ini
}

set_timezone()
{
    if [ -f /usr/share/zoneinfo/$TZ ]; then 
        rm -f /etc/localtime && ln -s /usr/share/zoneinfo/$TZ /etc/localtime
    fi
}

dir=(
    /etc/settings.ini
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
    /var/lib/mysql
    /var/lib/dirsrv
    /var/lib/imap
    /var/lib/nginx
    /var/lib/spamassassin
    /var/lib/clamav
    /var/spool/amavisd
    /var/spool/imap
    /var/spool/mail
    /var/spool/postfix
    /var/spool/opendkim
    /var/spool/pykolab
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


move_dirs()
{
    echo "info:  start moving lib and log folders to /data volume"

    mkdir -p /data/etc
    mkdir -p /data/var/lib
    mkdir -p /data/var/spool
    mkdir -p /data/var/log

    for i in "${dir[@]}"; do mv $i /data$i; done

    echo "info:  finished moving lib and log folders to /data volume"
}

link_dirs()
{
    echo "info:  start linking default lib and log folders to /data volume"

    for i in "${dir[@]}"; do rm -rf $i && ln -s /data$i $i ; done
 
    #Need for dirsrv
    mkdir /var/lock/dirsrv/slapd-$(hostname -s)/
    chown dirsrv:dirsrv /var/lock/dirsrv/slapd-$(hostname -s)/
    chown dirsrv:dirsrv /var/run/dirsrv

    echo "info:  finished linking default lib and log folders to /data volume"
}

configure_supervisor()
{
    echo "info:  start configuring Supervisor"

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
;[program:set_default_sieve]
;command=/bin/set_default_sieve.sh 
EOF

    echo "info:  finished configuring Supervisor"
}

configure_kolab()
{
    if [ ! -d /etc/dirsrv/slapd-* ] ; then 
        echo "info:  start configuring Kolab"

        #Fix apache symlinks
        rm -f /etc/httpd/modules && ln -s /usr/lib64/httpd/modules /etc/httpd/modules
        rm -f /etc/httpd/logs && ln -s /var/log/httpd /etc/httpd/logs
        rm -f /etc/httpd/run && ln -s /var/run /etc/httpd/run

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

        # Redirect to /webmail/ in apache
        sed -i -e 's/<Directory \/>/<Directory \/>\n    RedirectMatch \^\/$ \/webmail\//g' /etc/httpd/conf/httpd.conf

        # SSL by default in apache
        cat >> /etc/httpd/conf/httpd.conf << EOF

<VirtualHost _default_:80>
    RewriteEngine On
    RewriteRule ^(.*)$ https://%{HTTP_HOST}\$1 [R=301,L]
</VirtualHost>
EOF

        #fix: Certificates changed by default from localhost.pem to key and crt
        postconf -e smtpd_tls_key_file=/etc/pki/tls/private/localhost.key
        postconf -e smtpd_tls_cert_file=/etc/pki/tls/certs/localhost.crt

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
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 5m;
    ssl_prefer_server_ciphers on;
    ssl_stapling on;
    ssl_stapling_verify on;
    ssl on;
    ssl_certificate /etc/pki/tls/certs/localhost.crt;
    ssl_certificate_key /etc/pki/tls/private/localhost.key;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_ciphers 'HIGH:!aNULL:!MD5:!kEDH';
    add_header Strict-Transport-Security "max-age=31536000; includeSubdomains;";

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
        sed -i --follow-symlinks '/^[^;]*httpd/s/^/;/' /etc/supervisord.conf
        # Uncoment nginx and php-fpm
        sed -i --follow-symlinks '/^;.*nginx/s/^;//' /etc/supervisord.conf
        sed -i --follow-symlinks '/^;.*php-fpm/s/^;//' /etc/supervisord.conf

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
        a \    open_file_cache max=16384 inactive=5m;
        a \    open_file_cache_valid 90s; 
        a \    open_file_cache_min_uses 2;
        a \    open_file_cache_errors on;
        }' /etc/nginx/nginx.conf

        sed -i '/include \/etc\/nginx\/conf\.d\/\*.conf;/{
        a \    fastcgi_cache_key "$scheme$request_method$host$request_uri";
        a \    fastcgi_cache_use_stale error timeout invalid_header http_500;
        a \    fastcgi_cache_valid 200 302 304 10m;
        a \    fastcgi_cache_valid 301 1h; 
        a \    fastcgi_cache_min_uses 2; 
        }' /etc/nginx/nginx.conf

        sed -i '1ifastcgi_cache_path /var/lib/nginx/fastcgi/ levels=1:2 keys_zone=key-zone-name:16m max_size=256m inactive=1d;' /etc/nginx/conf.d/default.conf

        sed -i '/error_log/a \    fastcgi_cache key-zone-name;' /etc/nginx/conf.d/default.conf

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
        sed -i 's/^\($final_spam_destiny.*= \).*/\1D_PASS;/' /etc/amavisd/amavisd.conf

        # Create default sieve script
        cat > /var/lib/imap/sieve/global/default.script << EOF
require "fileinto";
if header :contains "X-Spam-Flag" "YES"
{
        fileinto "Spam";
}
EOF
        # Compile it
        /usr/lib/cyrus-imapd/sievec /var/lib/imap/sieve/global/default.script /var/lib/imap/sieve/global/default.bc
    
        # Uncoment set_default_sieve
        sed -i --follow-symlinks '/^;.*set_default_sieve/s/^;//' /etc/supervisord.conf

        echo "info:  finished configuring amavis"
    else
        echo "warn:  amavis already configured, skipping..."
    fi
}

configure_ssl()
{
    if [ -f /etc/pki/tls/certs/$(hostname -f).crt ] ; then
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

    if [ -f /etc/pki/tls/private/$(hostname -f).key ] ; then
	cat /etc/pki/tls/private/$(hostname -f).key /tmp/update_ssl_key_message.txt > /tmp/update_ssl_$(hostname -f).key
    else
	cat /tmp/update_ssl_key_message.txt > /tmp/update_ssl_$(hostname -f).key
    fi

    if [ -f /etc/pki/tls/certs/$(hostname -f).crt ] ; then
	cat /etc/pki/tls/certs/$(hostname -f).crt /tmp/update_ssl_crt_message.txt > /tmp/update_ssl_$(hostname -f).crt
    else
	cat /tmp/update_ssl_crt_message.txt > /tmp/update_ssl_$(hostname -f).crt
    fi
    if [ -f /etc/pki/tls/certs/$(hostname -f)-ca.pem ] ; then
	cat /etc/pki/tls/certs/$(hostname -f)-ca.pem /tmp/update_ssl_ca_message.txt > /tmp/update_ssl_$(hostname -f)-ca.pem
    else
	cat /tmp/update_ssl_ca_message.txt > /tmp/update_ssl_$(hostname -f)-ca.pem
    fi

    vi /tmp/update_ssl_$(hostname -f).key
    vi /tmp/update_ssl_$(hostname -f).crt
    vi /tmp/update_ssl_$(hostname -f)-ca.pem

    if [ "$(grep -c -v -E "^#|^$" /tmp/update_ssl_$(hostname -f).key)" != "0" ] || [ "$(grep -c -v -E "^#|^$" /tmp/update_ssl_$(hostname -f).crt)" != "0" ] || [ "$(grep -c -v -E "^#|^$" /tmp/update_ssl_$(hostname -f)-ca.pem)" != "0" ] ; then
        grep -v -E "^#|^$" /tmp/update_ssl_$(hostname -f).key > /etc/pki/tls/private/$(hostname -f).key
        grep -v -E "^#|^$" /tmp/update_ssl_$(hostname -f).crt > /etc/pki/tls/certs/$(hostname -f).crt
        grep -v -E "^#|^$" /tmp/update_ssl_$(hostname -f)-ca.pem > /etc/pki/tls/certs/$(hostname -f)-ca.pem

        # Create certificate bundles
        cat /etc/pki/tls/certs/$(hostname -f).crt /etc/pki/tls/private/$(hostname -f).key /etc/pki/tls/certs/$(hostname -f)-ca.pem > /etc/pki/tls/private/$(hostname -f).bundle.pem
        cat /etc/pki/tls/certs/$(hostname -f).crt /etc/pki/tls/certs/$(hostname -f)-ca.pem > /etc/pki/tls/certs/$(hostname -f).bundle.pem
        cat /etc/pki/tls/certs/$(hostname -f)-ca.pem > /etc/pki/tls/certs/$(hostname -f).ca-chain.pem
        # Set access rights
        chown -R root:mail /etc/pki/tls/private
        chmod 600 /etc/pki/tls/private/$(hostname -f).key
        chmod 750 /etc/pki/tls/private
        chmod 640 /etc/pki/tls/private/*
        # Add CA to system’s CA bundle
        cat /etc/pki/tls/certs/$(hostname -f)-ca.pem >> /etc/pki/tls/certs/ca-bundle.crt

        # Configure apache for SSL

        # Set your ssl certificates 
        sed -i -e '/SSLCertificateFile \/etc\/pki/c\SSLCertificateFile /etc/pki/tls/certs/'$(hostname -f)'.crt' /etc/httpd/conf.d/ssl.conf
        sed -i -e '/SSLCertificateKeyFile \/etc\/pki/c\SSLCertificateKeyFile /etc/pki/tls/private/'$(hostname -f)'.key' /etc/httpd/conf.d/ssl.conf
        sed -i -e '/SSLCertificateChainFile \/etc\/pki/c\SSLCertificateChainFile /etc/pki/tls/certs/'$(hostname -f)'.ca-chain.pem' /etc/httpd/conf.d/ssl.conf

        # Configuration nginx for SSL
        sed -i -e '/ssl_certificate /c\    ssl_certificate /etc/pki/tls/certs/'$(hostname -f)'.crt;' /etc/nginx/conf.d/default.conf
        sed -i -e '/ssl_certificate_key/c\    ssl_certificate_key /etc/pki/tls/private/'$(hostname -f)'.key;' /etc/nginx/conf.d/default.conf
        if [ "$(grep -c "ssl_trusted_certificate" /etc/nginx/conf.d/default.conf)" == "0" ] ; then
             sed -i -e '/ssl_certificate_key/a\    ssl_trusted_certificate /etc/pki/tls/certs/'$(hostname -f)'.ca-chain.pem;' /etc/nginx/conf.d/default.conf
        else 
             sed -i -e '/ssl_trusted_certificate/c\    ssl_trusted_certificate /etc/pki/tls/certs/'$(hostname -f)'.ca-chain.pem;' /etc/nginx/conf.d/default.conf
        fi

    
        #Configure Cyrus for SSL
        sed -r -i --follow-symlinks \
            -e 's|^tls_server_cert:.*|tls_server_cert: /etc/pki/tls/certs/'$(hostname -f)'.crt|g' \
            -e 's|^tls_server_key:.*|tls_server_key: /etc/pki/tls/private/'$(hostname -f)'.key|g' \
            -e 's|^tls_server_ca_file:.*|tls_server_ca_file: /etc/pki/tls/certs/'$(hostname -f)'.ca-chain.pem|g' \
            /etc/imapd.conf
    
        #Configure Postfix for SSL
        postconf -e smtpd_tls_key_file=/etc/pki/tls/private/$(hostname -f).key
        postconf -e smtpd_tls_cert_file=/etc/pki/tls/certs/$(hostname -f).crt
        postconf -e smtpd_tls_CAfile=/etc/pki/tls/certs/$(hostname -f).ca-chain.pem
    
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
        if [ "$(grep -c "calendar_caldav_url" /etc/roundcubemail/config.inc.php)" == "0" ] ; then
        cat >> /etc/roundcubemail/config.inc.php << EOF
# caldav/webdav
\$config['calendar_caldav_url']             = "https://%h/iRony/calendars/%u/%i";
\$config['kolab_addressbook_carddav_url']   = 'https://%h/iRony/addressbooks/%u/%i';
EOF
        fi

        if [ "$(grep -c "force_https" /etc/roundcubemail/config.inc.php)" == "0" ] ; then
        # Redirect all http traffic to https
        cat >> /etc/roundcubemail/config.inc.php << EOF
# Force https redirect for http requests
\$config['force_https'] = true;
EOF
	fi

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
        sed -i --follow-symlinks '/^;.*fail2ban/s/^;//' /etc/supervisord.conf

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
    
        sed -i --follow-symlinks 's/^\(^Mode\).*/\1  sv/' /etc/opendkim.conf

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
        sed -i --follow-symlinks '/^;.*opendkim/s/^;//' /etc/supervisord.conf

        echo "info:  finished configuring OpenDKIM"
    else
        echo "warn:  OpenDKIM already configured, skipping..."
    fi
}

kolab_rcpt_policy_off()
{
    echo "info:  start disabling recipient policy"
    if [ "$(grep -c "daemon_rcpt_policy" /etc/kolab/kolab.conf)" == "0" ] ; then
        sed -i -e '/\[kolab\]/a\daemon_rcpt_policy = False' /etc/kolab/kolab.conf
    else
        sed -i -e '/daemon_rcpt_policy/c\daemon_rcpt_policy = False' /etc/kolab/kolab.conf
    fi
    echo "info:  finished disabling recipient policy"
}

kolab_default_locale()
{
    echo "info:  start configuring kolab default locale"
    sed -i -e '/default_locale/c\default_locale = '$extras_kolab_default_locale /etc/kolab/kolab.conf
    echo "info:  finished configuring kolab default locale"
}

configure_size()
{
    echo "info:  start configuring sizes"
    sed -i --follow-symlinks -e '/memory_limit/c\memory_limit = '$extras_php_memory_limit /etc/php.ini
    sed -i --follow-symlinks -e '/upload_max_filesize/c\upload_max_filesize = '$extras_size_upload_max_filesize /etc/php.ini
    sed -i --follow-symlinks -e '/post_max_size/c\post_max_size = '$extras_size_post_max_size /etc/php.ini
    #sed -i -e '/php_value post_max_size/c\php_value post_max_size             '$extras_size_post_max_size /usr/share/chwala/public_html/.htaccess           
    #sed -i -e '/php_value upload_max_filesize/c\php_value upload_max_filesize             '$extras_size_upload_max_filesize /usr/share/chwala/public_html/.htaccess
    sed -i -e '/client_max_body_size/c\        client_max_body_size '$extras_nginx_client_max_body_size';' /etc/nginx/conf.d/default.conf 

    # Convert megabytes to bytes for postfix
    if [[ $extras_size_post_max_size == *"M" ]] ;  then extras_postfix_message_size_limit=$[($(echo $extras_size_post_max_size | sed 's/[^0-9]//g'))*1024*1024] ; fi
    postconf -e message_size_limit=$extras_postfix_message_size_limit    

    echo "info:  finished configuring sizes"
}

roundcube_larry_skin()
{
    echo "info:  start configuring Larry skin as default"
    sed -i "s/\$config\['skin'\] = '.*';/\$config\['skin'\] = 'larry';/g" /etc/roundcubemail/config.inc.php
    echo "info:  finished configuring Larry skin as default"
}

roundcube_zipdownload()
{
    if [ "$(grep -c "zipdownload" /etc/roundcubemail/config.inc.php)" == "0" ] ; then
        echo "info:  start configuring zipdownload plugin"
        sed -i "/'contextmenu',/a \            'zipdownload'," /etc/roundcubemail/config.inc.php
        echo "info:  finished configuring zipdownload plugin"
    else
        echo "warn:  zipdownload plugin already configured, skipping..."
    fi
}

roundcube_trash_folder()
{
    echo "info:  start configuring trash folder istead flaging"
    sed -i "s/\$config\['skip_deleted'\] = '.*';/\$config\['skip_deleted'\] = 'false';/g" /etc/roundcubemail/config.inc.php
    sed -i "s/\$config\['flag_for_deletion'\] = '.*';/\$config\['flag_for_deletion'\] = 'false';/g" /etc/roundcubemail/config.inc.php
    echo "info:  finished configuring trash folder istead flaging"
}

postfix_milter()
{
    if [ "$(grep "smtpd_milters" /etc/postfix/main.cf | grep -cv localhost)" != "0" ] ; then
        echo "warn:  another milter already configured, but that's nothing wrong, run again..."
    fi

    echo "info:  start configuring zipdownload plugin"

    #Reconfigure OpenDKIM
    if [ "$(postconf smtpd_milters | grep -c inet:localhost:8891)" != "0" ] && [ "$(grep -c "smtpd_milters=inet:localhost:8891" /etc/postfix/master.cf)" == "0" ] ; then
        sed -i "/^127\.0\.0\.1\:10027.*smtpd/a \    -o smtpd_milters=inet:localhost:8891" /etc/postfix/master.cf
        sed -i "/^127\.0\.0\.1\:10027.*smtpd/a \    -o milter_protocol=2" /etc/postfix/master.cf
    fi

    postconf -e milter_protocol=$extras_another_milter_protocol
    postconf -e smtpd_milters=$extras_another_milter_address
    postconf -e non_smtpd_milters=$extras_another_milter_address
    postconf -e content_filter=smtp-wallace:[127.0.0.1]:10026
    
    #Disable amavis
    awk '/smtp-amavis/{f=1} !NF{f=0} f{$0="#" $0} 1' /etc/postfix/master.cf > /tmp/master.cf.tmp
    awk '/127.0.0.1:10025/{f=1} !NF{f=0} f{$0="#" $0} 1' /tmp/master.cf.tmp > /etc/postfix/master.cf
    rm -f /tmp/master.cf.tmp

    sed -i '/^[^#].*receive_override_options=no_milters/d' /etc/postfix/master.cf

    # Comment amavis and clamd
    sed -i --follow-symlinks '/^[^;]*amavisd/s/^/;/' /etc/supervisord.conf
    sed -i --follow-symlinks '/^[^;]*clamd/s/^/;/' /etc/supervisord.conf

    echo "info:  finished configuring zipdownload plugin"
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

setup_wizard ()
{
    vi /etc/settings.ini
    get_config /etc/settings.ini
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
    if [ $extras_kolab_rcpt_policy_off = "true" ] ; then kolab_rcpt_policy_off ; fi
    if [ $extras_kolab_default_locale != "" ] ; then kolab_default_locale ; fi
    if [ $extras_php_memory_limit != "" ] && [ $extras_size_upload_max_filesize != "" ] && [ $extras_size_post_max_size != "" ] ; then configure_size ; fi
    if [ $extras_roundcube_larry_skin = "true" ] ; then roundcube_larry_skin ; fi
    if [ $extras_roundcube_zipdownload = "true" ] ; then roundcube_zipdownload ; fi
    if [ $extras_roundcube_trash_folder = "true" ] ; then roundcube_trash_folder ; fi
    if [ $extras_postfix_another_milter = "true" ] ; then postfix_milter ; fi
    # Print parameters
    if [ $main_configure_kolab = "true" ] ; then print_passwords ; fi
    if [ $main_configure_dkim = "true" ] ; then print_dkim_keys ; fi
}

run ()
{
     if [ -d /data/etc/dirsrv/slapd-* ] ; then
     
         echo "info:  Kolab installation detected on /data volume, run relinkink..."
         link_dirs
         
         echo "info:  Starting services"
         /usr/bin/supervisord
     
     else
     
          while true; do
             read -p "warn:  Kolab data not detected on /data volume, this is first installation(yes/no)? " yn
             case $yn in
                 [Yy]* ) move_dirs; link_dirs; setup_wizard; break;;
                 [Nn]* ) echo "info:  Installation canceled"; exit;;
                 * ) echo "Please answer yes or no.";;
             esac
         done
     
     fi
}

set_timezone

if [ -f /data/etc/settings.ini ]; then get_config /data/etc/settings.ini; fi

case "$1" in
    "run")          run ;;
    "kolab")        configure_kolab ; print_passwords ;;
    "nginx")        configure_nginx ;;
    "nginx_cache")  configure_nginx_cache ;;
    "amavis")       configure_amavis ;;
    "ssl")          configure_ssl ;;
    "fail2ban")     configure_fail2ban ;;
    "dkim")         configure_dkim ; print_dkim_keys ;;
    "rcpt_off")     kolab_rcpt_policy_off ;;
    "locale")       kolab_default_locale ;;
    "size")         configure_size ;;
    "larry")        roundcube_larry_skin ;;
    "zipdownload")  roundcube_zipdownload ;;
    "trash")        roundcube_trash_folder ;;
    "milter")       postfix_milter ;;
    "link")         link_dirs ;;
    *)              usage ;;
esac

