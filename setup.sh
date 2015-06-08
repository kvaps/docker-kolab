#!/bin/bash
usage ()
{
     echo
     echo "Usage:    ./setup.sh [ARGUMENT]"
     echo
     echo "Arguments:"
     echo "    kolab                 - Configure Kolab"
     echo "    nginx                 - Configure nginx"
     echo "    ssl                   - Configure SSL"
     echo "    opendkim              - Configure OpenDKIM"
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
set_hostname()
{
    old_hostname="$(cat /etc/hosts | awk 'NR == 1{print $2}')"
    new_hostname="$(echo $main_hostname | cut -d. -f1)"
    new_domain="$(echo $main_hostname | cut -d. -f2-)"
    echo $main_hostname > /etc/hostname
    sed -e "s/$old_hostname.*$/$main_hostname\ $new_hostname/g" /etc/hosts | tee /etc/hosts
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
}

configure_nginx() {
    # This section is made using the official kolab wiki-page:
    # https://docs.kolab.org/howtos/nginx-webserver.html

    yum -y install nginx php-fpm

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
    access_log /var/log/nginx/$main_hostname-access_log;
    error_log /var/log/nginx/$main_hostname-error_log;

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

sed '/^\[kolab_wap\]/,/^\[/ { x; /^$/ !{ x; H }; /^$/ { x; h; }; d; }; x; /^\[kolab_wap\]/ { s/\(\n\+[^\n]*\)$/\napi_url = https:\/\/'$main_hostname'\/kolab-webadmin\/api\1/; p; x; p; x; d }; x' /etc/kolab/kolab.conf

sed -i "s/\$config\['assets_path'\] = '.*';/\$config\['assets_path'\] = '\/assets\/';/g" /etc/roundcubemail/config.inc.php

    service php-fpm start
    #chkconfig php-fpm on
    service nginx start
    #chkconfig nginx on

}

configure_ssl()
{
#Configure Apache for SSL
sed -i -e '/SSLCertificateFile \/etc\/pki/c\SSLCertificateFile /etc/pki/tls/certs/domain.crt' /etc/httpd/conf.d/ssl.conf
sed -i -e '/SSLCertificateKeyFile \/etc\/pki/c\SSLCertificateKeyFile /etc/pki/tls/private/domain.key' /etc/httpd/conf.d/ssl.conf
sed -i -e '/SSLCertificateChainFile \/etc\/pki/c\SSLCertificateChainFile /etc/pki/tls/certs/domain.ca-chain.pem' /etc/httpd/conf.d/ssl.conf
sed -i '/<VirtualHost _default_:443>/a Include conf.d/roundcubemail.conf' /etc/httpd/conf.d/ssl.conf

#Configure Cyrus for SSL
sed -r -i \
    -e 's|^tls_cert_file:.*|tls_cert_file: /etc/pki/tls/certs/domain.crt|g' \
    -e 's|^tls_key_file:.*|tls_key_file: /etc/pki/tls/private/domain.key|g' \
    -e 's|^tls_ca_file:.*|tls_ca_file: /etc/pki/tls/certs/domain.ca-chain.pem|g' \
    /etc/imapd.conf

#Configure Postfix for SSL
postconf -e smtpd_tls_key_file=/etc/pki/tls/private/domain.key
postconf -e smtpd_tls_cert_file=/etc/pki/tls/certs/domain.crt
postconf -e smtpd_tls_CAfile=/etc/pki/tls/certs/domain.ca-chain.pem

#Configure kolab-cli for SSL
sed -r -i \
    -e '/api_url/d' \
    -e "s#\[kolab_wap\]#[kolab_wap]\napi_url = https://`cat /root/hostname`/kolab-webadmin/api#g" \
    /etc/kolab/kolab.conf

#Configure Roundcube for SSL
sed -i -e '/kolab_ssl/d' /etc/roundcubemail/libkolab.inc.php
sed -i -e 's/http:/https:/' /etc/roundcubemail/libkolab.inc.php
sed -i -e 's/http:/https:/' /etc/roundcubemail/kolab_files.inc.php
sed -i -e '/^?>/d' /etc/roundcubemail/config.inc.php
cat < /root/roundcubemailconfig.inc.php >> /etc/roundcubemail/config.inc.php
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




if [ "$1" = "--help" ] || [ "$1" = "-h" ] || [ "$1" = "help" ] ; then 
    usage
fi

get_config settings.ini

if [[ $main_configure_kolab == "true" ]] || [ "$1" = "kolab" ] ; then
    configure_kolab
fi

if [[ $main_configure_nginx == "true" ]] || [ "$1" = "nginx" ] ; then
    configure_nginx
fi

if [ ! $1 ] || [ "$1" = "kolab" ] ; then
print_passwords
fi
