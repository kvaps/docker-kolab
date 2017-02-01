#!/bin/bash

KOLAB_CONF=`          readlink -f "/etc/kolab/kolab.conf"`
ROUNDCUBE_CONF=`      readlink -f "/etc/roundcubemail/config.inc.php"`
PHP_CONF=`            readlink -f "/etc/php.ini"`
AMAVISD_CONF=`        readlink -f "/etc/amavisd/amavisd.conf"`
OPENDKIM_CONF=`       readlink -f "/etc/opendkim.conf"`
NGINX_CONF=`          readlink -f "/etc/nginx/nginx.conf"`
NGINX_DEFAULT_CONF=`  readlink -f "/etc/nginx/conf.d/default.conf"`
HTTPD_CONF=`          readlink -f "/etc/httpd/conf/httpd.conf"`
HTTPD_SSL_CONF=`      readlink -f "/etc/httpd/conf.d/ssl.conf"`
HTTPD_ROUNDCUBE_CONF=`readlink -f "/etc/httpd/conf.d/roundcubemail.conf"`
IMAPD_CONF=`          readlink -f "/etc/imapd.conf"`
POSTFIX_MASTER_CONF=` readlink -f "/etc/postfix/master.cf"`
FAIL2BAN_JAIL_CONF=`  readlink -f "/etc/fail2ban/jail.conf"`

function chk_env {
    eval env="\$$1"
    val="${env:-$2}"
    if [ -z "$val" ]; then
        >&2 echo "chk_env: Enviroment vaiable \$$1 is not set."
        exit 1
    fi  
    export "$1"="$val"
}

function configure {
    local VARIABLE="$1"
    eval local STATE="\$$VARIABLE"
    local CHECKS="${@:2}"
    if [ -z $STATE ] ; then
        echo "configure: Skiping configure_${VARIABLE,,}, because \$$VARIABLE is not set"
        return 0
    fi
    if ! [ -z "$CHECKS" ] && ! [[ " ${CHECKS[@]} " =~ " ${STATE} " ]] ; then
        >&2 echo "configure: Unknown state $STATE for \$$VARIABLE (need: `echo $CHECKS | sed 's/ /|/g'`)"
        exit 1
    fi

    echo Configuring ${VARIABLE,,} ${STATE}
    configure_${VARIABLE,,} ${STATE} || ( >&2 echo "configure: Error executing configure_${VARIABLE,,} ${STATE}" ; exit 1)
}

# Main functions

function image_services_stop {
    # Stop services
    RUNNING_SERVICES=($(systemctl list-units | grep running | awk '{print $1}' | grep -v '^systemd-\|start.service\|^dbus'))
    echo systemctl stop ${RUNNING_SERVICES[@]}
    systemctl stop ${RUNNING_SERVICES[@]}
}

function detect_old_image {
    if [ -d /data/etc ] || [ -d /data/var/lib ] || [ -d /data/var/log ] || [ -d /data/var/spool ] ; then
        >&2 echo
        >&2 echo "============================================="
        >&2 echo "Old Kolab 3.4 directories structure detected!"
        >&2 echo "============================================="
        >&2 echo
        >&2 echo "Please move your data directories to separate storages like:"
        >&2 echo
        >&2 echo "    # mv ./data/etc/* ./config/"
        >&2 echo "    # mv ./data/var/lib/* ./data/"
        >&2 echo "    # mv ./data/var/log/* ./log/"
        >&2 echo "    # mv ./data/var/spool/* ./spool/"
        >&2 echo "    # rmdir ./data/etc/ ./data/var/* ./data/var/"
        >&2 echo
        >&2 echo "After it, don't forget to create version.conf file:"
        >&2 echo
        >&2 echo "    # mkdir -p ./config/image"
        >&2 echo "    # echo '3.4-0' > ./config/image/version.conf"
        >&2 echo

        exit 1
    fi
}

function setup_kolab {
    chk_env LDAP_ADMIN_PASS
    chk_env LDAP_MANAGER_PASS
    chk_env LDAP_CYRUS_PASS
    chk_env LDAP_KOLAB_PASS
    chk_env MYSQL_ROOT_PASS
    chk_env MYSQL_KOLAB_PASS
    chk_env MYSQL_ROUNDCUBE_PASS

    # Run setup-kolab
    /lib/start/setup-kolab.exp
    setup_kolab_after
}

function setup_kolab_after {

    # Alias for /webmail/ in apache
    sed -i \
        -e '1iAlias / /usr/share/roundcubemail/public_html/' \
        -e 's:RewriteCond %{REQUEST_URI}  ^/(roundcubemail|webmail):RewriteCond %{REQUEST_URI}  ^/(|roundcubemail|webmail):' \
        $HTTPD_ROUNDCUBE_CONF

    # Set hostname for Amavisd
    sed -i 's/^[# ]*$myhostname.*$/$myhostname = "'$(hostname -f)'";/' $AMAVISD_CONF

    # Create or Move /etc/aliases.db to /config/aliases.db
    if [ ! -f $(readlink -f /etc/aliases.db) ] ; then
        postalias /config/aliases
        rm -f /etc/aliases.db
        ln -s /config/aliases.db /etc/aliases.db
    elif [ "$(readlink -f /etc/aliases.db)" == "/etc/aliases.db" ] ; then
        mv /etc/aliases.db /config/aliases.db
        ln -s /config/aliases.db /etc/aliases.db
    fi

    # Create logfiles
    local LOGFILES=(
        /var/log/maillog
        /var/log/maillog
        /var/log/roundcubemail/userlogins
        /var/log/iRony/userlogins
        /var/log/chwala/userlogins
        /var/log/kolab-syncroton/userlogins
        /var/log/kolab-webadmin/auth_fail.log
    )
    for LOGFILE in ${LOGFILES[@]}; do
        mkdir -p $(dirname $LOGFILE)
        touch $LOGFILE
    done
    
    image_services_stop
}

function configure_webserver {
    case $1 in
        nginx  ) 
            # Manage services
            export SERVICE_HTTPD=false
            export SERVICE_NGINX=true
            export SERVICE_PHP_FPM=true

            # Conigure Kolab for nginx
            crudini --set $KOLAB_CONF kolab_wap api_url "https://$(hostname -f)/kolab-webadmin/api"
            roundcube_conf --set $ROUNDCUBE_CONF assets_path "/assets/"
            roundcube_conf --set $ROUNDCUBE_CONF ssl_verify_peer false
            roundcube_conf --set $ROUNDCUBE_CONF ssl_verify_host false
        ;;
        apache )
            # Manage services
            export SERVICE_HTTPD=true
            export SERVICE_NGINX=false
            export SERVICE_PHP_FPM=false

            # Conigure Kolab for apache
            crudini --del $KOLAB_CONF kolab_wap api_url
            roundcube_conf --del $ROUNDCUBE_CONF assets_path
            roundcube_conf --del $ROUNDCUBE_CONF ssl_verify_peer
            roundcube_conf --del $ROUNDCUBE_CONF ssl_verify_host
        ;;
    esac
}

function configure_force_https {
    case $1 in
        true  ) 
            if ! $(grep -q '<VirtualHost _default_:80>' $HTTPD_CONF) ; then
                echo -e '<VirtualHost _default_:80>\n    RewriteEngine On\n    RewriteRule (.*) https://%{HTTP_HOST}%{REQUEST_URI} [R=301,L]\n</VirtualHost>' >> $HTTPD_CONF
            fi
            sed -i -e '0,/^}/ {/listen 80/,/^}/ {s|include /etc/nginx/kolab.conf;|location / {\n        return 301 https://$host$request_uri;\n    }|}}' $NGINX_DEFAULT_CONF
        ;;
        false )
            sed -i -e '/\<VirtualHost _default_:80>/,/<\/VirtualHost>/d' $HTTPD_CONF
            sed -i -r \
                -e '0,/^}/ {/listen 80/,/^}/ {/location \/ {/,/}/d}}' \
                -e '0,/^}/ {/listen 80/,/^}/ s|^}|    include /etc/nginx/kolab.conf\n}|}' \
            $NGINX_DEFAULT_CONF
        ;;
    esac
}

function configure_nginx_cache {
    case $1 in
        true  ) 
            # Configure nginx cache
            if [ ! $(grep -q open_file_cache /etc/nginx/nginx.conf) ] ; then
                #Adding open file cache to nginx
                sed -i '/include \/etc\/nginx\/conf\.d\/\*.conf;/{
                a \    open_file_cache max=16384 inactive=5m;
                a \    open_file_cache_valid 90s; 
                a \    open_file_cache_min_uses 2;
                a \    open_file_cache_errors on;
                }' $NGINX_CONF

                sed -i '/include \/etc\/nginx\/conf\.d\/\*.conf;/{
                a \    fastcgi_cache_key "$scheme$request_method$host$request_uri";
                a \    fastcgi_cache_use_stale error timeout invalid_header http_500;
                a \    fastcgi_cache_valid 200 302 304 10m;
                a \    fastcgi_cache_valid 301 1h; 
                a \    fastcgi_cache_min_uses 2; 
                }' $NGINX_CONF

                sed -i '1ifastcgi_cache_path /var/lib/nginx/fastcgi/ levels=1:2 keys_zone=key-zone-name:16m max_size=256m inactive=1d;' $NGINX_DEFAULT_CONF
                sed -i '/error_log/a \    fastcgi_cache key-zone-name;' $NGINX_DEFAULT_CONF
            fi
        ;;
        false )
            # Configure nginx cache
            sed -i '/open_file_cache/d' $NGINX_CONF
            sed -i '/fastcgi_cache/d' $NGINX_CONF
            sed -i '/fastcgi_cache/d' $NGINX_DEFAULT_CONF
        ;;
    esac
}

function configure_spam_sieve {
    case $1 in
        true  ) 
            # Manage services
            export SERVICE_SET_SPAM_SIEVE=true

            # Set timeout
            echo "SPAM_SIEVE_TIMEOUT=\"$SPAM_SIEVE_TIMEOUT\"" >/etc/default/set_spam_sieve

            # Configure amavis
            sed -i '/^[^#]*$sa_spam_subject_tag/s/^/#/' $AMAVISD_CONF
            sed -i 's/^\($final_spam_destiny.*= \).*/\1D_PASS;/' $AMAVISD_CONF
            sed -r -i "s/^\\\$mydomain = '[^']*';/\\\$mydomain = '$(hostname -d)';/" $AMAVISD_CONF
        ;;
        false )
            # Manage services
            export SERVICE_SET_SPAM_SIEVE=false

            # Configure amavis
            sed -i '/^#i.*$sa_spam_subject_tag/s/^#//' $AMAVISD_CONF
            sed -i 's/^\($final_spam_destiny.*= \).*/\1D_DISCARD;/' $AMAVISD_CONF
        ;;
    esac
}

function configure_fail2ban {
    case $1 in
        true  ) 
            # Manage services
            export SERVICE_RSYSLOG=true
            export SERVICE_FAIL2BAN=true
            crudini --set $FAIL2BAN_JAIL_CONF DEFAULT bantime $FAIL2BAN_BANTIME

            # Enable logging for kolab-webadmin
            (
                PATCH=/lib/start/kolab-webadmin.patch
                FILE=/usr/share/kolab-webadmin/lib/kolab_client_task.php
                patch -p4 -N --dry-run --silent $FILE < $PATCH 2>/dev/null
                if [ $? -eq 0 ]; then patch -p4 -N $FILE < $PATCH ;fi
            )
            touch /var/log/kolab-webadmin/auth_fail.log
       ;;
       false )
            # Manage services
            export SERVICE_FAIL2BAN=false

            # Disable logging for kolab-webadmin
            (
                PATCH=/lib/start/kolab-webadmin.patch
                FILE=/usr/share/kolab-webadmin/lib/kolab_client_task.php
                patch -R -p4 -N --dry-run --silent $FILE < $PATCH 2>/dev/null
                if [ $? -eq 0 ]; then patch -R -p4 -N $FILE < $PATCH ;fi
            )
       ;;
    esac
}

function configure_dkim {
    case $1 in
        true  ) 
            # Manage services
            export SERVICE_OPENDKIM=true

            # Configure OpenDKIM
            if [ ! -f "/etc/opendkim/keys/$(hostname -s).private" ]; then 
                opendkim-genkey -D /etc/opendkim/keys/ -d $(hostname -d) -s $(hostname -s)
                chgrp opendkim /etc/opendkim/keys/*
                chmod g+r /etc/opendkim/keys/*
            fi

            opendkim_conf --set $OPENDKIM_CONF Mode sv
            opendkim_conf --set $OPENDKIM_CONF KeyTable "/etc/opendkim/KeyTable"
            opendkim_conf --set $OPENDKIM_CONF SigningTable "/etc/opendkim/SigningTable"
            opendkim_conf --set $OPENDKIM_CONF X-Header yes
        
            echo $(hostname -f | sed s/\\./._domainkey./) $(hostname -d):$(hostname -s):$(ls /etc/opendkim/keys/*.private) | cat > /etc/opendkim/KeyTable
            echo $(hostname -d) $(echo $(hostname -f) | sed s/\\./._domainkey./) | cat > /etc/opendkim/SigningTable
        
            # Conigure Postfix
            postconf -e milter_default_action=accept
            if ! $(postconf smtpd_milters | grep -q inet:localhost:8891) && ! $(grep -q "smtpd_milters=inet:localhost:8891" $POSTFIX_MASTER_CONF) ; then
                sed -i "/^127\.0\.0\.1\:10025.*smtpd/a \    -o receive_override_options=no_milters" $POSTFIX_MASTER_CONF
                sed -i "/^127\.0\.0\.1\:10027.*smtpd/a \    -o smtpd_milters=inet:localhost:8891\n    -o milter_protocol=2" $POSTFIX_MASTER_CONF
            fi

        ;;
        false )
            # Manage services
            export SERVICE_OPENDKIM=false

            # Conigure Postfix
            if $(postconf smtpd_milters | grep -q inet:localhost:8891) || $(grep -q "smtpd_milters=inet:localhost:8891" $POSTFIX_MASTER_CONF) ; then
                sed -i "N;N; s/\(127\.0\.0\.1\:10027.*smtpd\)\n    -o smtpd_milters=inet:localhost:8891\n    -o milter_protocol=2/\\1/g" $POSTFIX_MASTER_CONF
                sed -i "N; s/\(127\.0\.0\.1\:10025.*smtpd\)\n    -o receive_override_options=no_milters/\\1/" $POSTFIX_MASTER_CONF
            fi
        ;;
    esac
}

function configure_syslog {
    case $1 in
        true  ) 
            # Manage services
            export SERVICE_RSYSLOG=true
        ;;
        false )
            # Manage services
            export SERVICE_RSYSLOG=false
        ;;
    esac
}


function configure_cert_path {

    if [ ! -d $CERT_PATH ]; then
        local domain_cers=${CERT_PATH}/$(hostname -f)
        mkdir -p "${domain_cers}"
    else
        if [ -d "${CERT_PATH}/$(hostname -f)" ]; then
            local domain_cers="${CERT_PATH}/$(hostname -f)"
        elif [ -d "$(dirname $(readlink -f $(find ${CERT_PATH} -name cert.pesm -print | head -n 1) 2> /dev/null) 2> /dev/null)" ]; then
            local domain_cers="$(dirname $(readlink -f $(find ${CERT_PATH} -name cert.pesm -print | head -n 1) 2> /dev/null) 2> /dev/null)"
        else
            echo "configure_cert_path:  no certificates found in $CERT_PATH fallback to /etc/pki/tls/kolab"
            export CERT_PATH="/etc/pki/tls/kolab"
            local domain_cers=${CERT_PATH}/$(hostname -f)
            mkdir -p "${domain_cers}"
        fi
    fi

    local certificate_path=${domain_cers}/cert.pem
    local privkey_path=${domain_cers}/privkey.pem
    local chain_path=${domain_cers}/chain.pem
    local fullchain_path=${domain_cers}/fullchain.pem

    if [ ! -f "$certificate_path" ] || [ ! -f "$privkey_path" ] ; then
        # Generate key and certificate
        openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 \
                    -subj "/CN=$(hostname -f)" \
                    -keyout $privkey_path \
                    -out $certificate_path
        # Set access rights
        chown -R root:mail ${domain_cers}
        chmod 750 ${domain_cers}
        chmod 640 ${domain_cers}/*
    fi
    
    # Configure apache for SSL
    sed -i -e "/^[^#]*SSLCertificateFile /c\SSLCertificateFile $certificate_path" $HTTPD_SSL_CONF
    sed -i -e "/^[^#]*SSLCertificateKeyFile /c\SSLCertificateKeyFile $privkey_path" $HTTPD_SSL_CONF
    if [ -f "$chain_path" ]; then
        if `sed 's/#.*$//g' /etc/httpd/conf.d/ssl.conf | grep -q SSLCertificateChainFile` ; then
            sed -i -e "/^[^#]*SSLCertificateChainFile: /cSSLCertificateChainFile: $chain_path" $HTTPD_SSL_CONF
        else
            sed -i -e "/^[^#]*SSLCertificateFile/aSSLCertificateChainFile: $chain_path" $HTTPD_SSL_CONF
        fi
    else
        sed -i -e "/SSLCertificateChainFile/d" $HTTPD_SSL_CONF
    fi
    
    # Configuration nginx for SSL
    if [ -f "$fullchain_path" ]; then
        sed -i -e "/ssl_certificate /c\    ssl_certificate $fullchain_path;" $NGINX_DEFAULT_CONF
    else
        sed -i -e "/ssl_certificate /c\    ssl_certificate $certificate_path;" $NGINX_DEFAULT_CONF
    fi
    sed -i -e "/ssl_certificate_key/c\    ssl_certificate_key $privkey_path;" $NGINX_DEFAULT_CONF
    
    #Configure Cyrus for SSL
    sed -r -i --follow-symlinks \
        -e "s|^tls_server_cert:.*|tls_server_cert: $certificate_path|g" \
        -e "s|^tls_server_key:.*|tls_server_key: $privkey_path|g" \
        $IMAPD_CONF

    if [ -f "$chain_path" ]; then
        if grep -q tls_server_ca_file $IMAPD_CONF ; then
            sed -i --follow-symlinks -e "s|^tls_server_ca_file:.*|tls_server_ca_file: $chain_path|g" $IMAPD_CONF
        else
            sed -i --follow-symlinks -e "/tls_server_cert/atls_server_ca_file: $chain_path" $IMAPD_CONF
        fi
    else
        sed -i --follow-symlinks -e "/^tls_server_ca_file/d" $IMAPD_CONF
    fi
        
    #Configure Postfix for SSL
    postconf -e smtpd_tls_key_file=$privkey_path
    postconf -e smtpd_tls_cert_file=$certificate_path
    if [ -f "$chain_path" ]; then
        postconf -e smtpd_tls_CAfile=$chain_path
    else
        postconf -X smtpd_tls_CAfile
    fi
}

function configure_kolab_default_quota {
    local SIZE=$KOLAB_DEFAULT_QUOTA
    # Convert megabytes to bytes for kolab.conf
    case $SIZE in
    *"G" ) SIZE=$[ ($(echo $SIZE | sed 's/[^0-9]//g'))*1024 ];;
    *"M" ) SIZE=$[ ($(echo $SIZE | sed 's/[^0-9]//g')) ];;
    *"K" ) SIZE=$[ ($(echo $SIZE | sed 's/[^0-9]//g'))/1024 ];;
    *    ) SIZE=$[ ($(echo $SIZE | sed 's/[^0-9]//g'))/1024/1024 ];;
    esac
    crudini --set $KOLAB_CONF kolab default_quota $SIZE
}

function configure_kolab_default_locale {
    crudini --set $KOLAB_CONF kolab default_locale "$KOLAB_DEFAULT_LOCALE"
}

function configure_max_memory_size {
    crudini --set $PHP_CONF php memory_limit $MAX_MEMORY_SIZE
}

function configure_max_file_size {
    crudini --set $PHP_CONF php upload_max_filesize $MAX_FILE_SIZE
}

function configure_max_mail_size {
    local SIZE=$MAX_MAIL_SIZE
    # Convert megabytes to bytes for postfix
    case $SIZE in
    *"G" ) SIZE=$[ ($(echo $SIZE | sed 's/[^0-9]//g'))*1024*1024*1024 ];;
    *"M" ) SIZE=$[ ($(echo $SIZE | sed 's/[^0-9]//g'))*1024*1024 ];;
    *"K" ) SIZE=$[ ($(echo $SIZE | sed 's/[^0-9]//g'))*1024 ];;
    *    ) SIZE=$[ ($(echo $SIZE | sed 's/[^0-9]//g')) ];;
    esac
    postconf -e message_size_limit=$SIZE
}

function configure_max_mailbox_size {
    local SIZE=$MAX_MAILBOX_SIZE
    # Convert megabytes to bytes for postfix
    case $SIZE in
    *"G" ) SIZE=$[ ($(echo $SIZE | sed 's/[^0-9]//g'))*1024*1024*1024 ];;
    *"M" ) SIZE=$[ ($(echo $SIZE | sed 's/[^0-9]//g'))*1024*1024 ];;
    *"K" ) SIZE=$[ ($(echo $SIZE | sed 's/[^0-9]//g'))*1024 ];;
    *    ) SIZE=$[ ($(echo $SIZE | sed 's/[^0-9]//g')) ];;
    esac
    postconf -e mailbox_size_limit=$SIZE
}

function configure_max_body_size {
    sed -i -e '/client_max_body_size/c\        client_max_body_size '$MAX_BODY_SIZE';' $NGINX_DEFAULT_CONF
}

function configure_roundcube_skin {
    roundcube_conf --set $ROUNDCUBE_CONF skin $ROUNDCUBE_SKIN
}

function configure_roundcube_trash {
    case $1 in
        trash )
            roundcube_conf --set $ROUNDCUBE_CONF skip_deleted false
            roundcube_conf --set $ROUNDCUBE_CONF flag_for_deletion false
        ;;
        flag )
            roundcube_conf --set $ROUNDCUBE_CONF skip_deleted true
            roundcube_conf --set $ROUNDCUBE_CONF flag_for_deletion true
        ;;
        esac
}

function configure_ext_milter_addr {
    if [ ! -z $1 ] ; then
        # Manage services
        export SERVICE_AMAVISD=false
        export SERVICE_CLAMD=false

        postconf -e milter_protocol=$EXT_MILTER_PROTO
        postconf -e smtpd_milters=$EXT_MILTER_ADDR
        postconf -e non_smtpd_milters=$EXT_MILTER_ADDR
        postconf -e content_filter=smtp-wallace:[127.0.0.1]:10026

        # Disable amavis chain
        sed -i '/^smtp-amavis/,/^$/ {/^[^$]/ s/^/#/}' $POSTFIX_MASTER_CONF
        sed -i '/^127.0.0.1:10025/,/^$/ {/^[^$]/ s/^/#/}' $POSTFIX_MASTER_CONF
    else
        # Conigure Postfix for external milter
        postconf -X milter_protocol
        postconf -X smtpd_milters
        postconf -X non_smtpd_milters
        postconf -e content_filter=smtp-amavis:[127.0.0.1]:10024

        # Enable amavis chain
        sed -i '/^#smtp-amavis/,/^$/ {/^[^$]/ s/^#//}' $POSTFIX_MASTER_CONF 
        sed -i '/^#127.0.0.1:10025/,/^$/ {/^[^$]/ s/^#//}' $POSTFIX_MASTER_CONF
    fi
}

function configure_roundcube_plugins {
    local roundcube_plugins=($(env | grep -oP '(?<=^ROUNDCUBE_PLUGIN_)[a-zA-Z0-9_]*'))
    for plugin_var in ${roundcube_plugins[@]} ; do
        local plugin_dir="/usr/share/roundcubemail/plugins"
        local plugin_mask=$(echo $plugin_var | sed 's/_/.?/g')
        local plugin_name=$(ls $plugin_dir -1 | grep -iE "^$plugin_mask$")
        eval local plugin_state=\$ROUNDCUBE_PLUGIN_${plugin_var}

        if $(echo $plugin_name | grep -q ' '); then
            >&2 echo "configure_roundcube_plugins: Duplicate roundcube plugins: $(echo $plugin_name)"
            exit 1
        elif [ -z "$plugin_name" ]; then
            >&2 echo "configure_roundcube_plugins:  Roundcube plugin ${plugin_var,,} not found in $plugin_dir"
            exit 1
        elif ! ( [ "$plugin_state" == true ] || [ "$plugin_state" == false ] ); then
            >&2 echo "configure_roundcube_plugins: Unknown state $plugin_state for roundcube plugin ${plugin_name} (need: true|false)"
            exit 1
        fi

        echo Configuring roundcube plugins
        configure_roundcube_plugin $plugin_name $plugin_state
    done
}

# Addition functions

function configure_roundcube_plugin {
    local PLUGIN=$1
    local STATE=$2
    case $STATE in
        true  )
            echo Enabling $PLUGIN plugin
            if ! $(sed -n '/\$config\['\''plugins'\''\] = array(/,/[^)]);/p' $ROUNDCUBE_CONF | grep -q \'$PLUGIN\') ; then
                sed -i '/\$config\['\''plugins'\''\] = array(/,/[^)]);/ s/);/    '\'$PLUGIN'\'',\n        );/' $ROUNDCUBE_CONF
            fi
        ;;
        false )
            echo Disabling $PLUGIN plugin
            sed -i '/\$config\['\''plugins'\''\] = array(/,/[^)]);/ {/'\'$PLUGIN\''/d}' $ROUNDCUBE_CONF
        ;;
    esac
}

function roundcube_conf {
    local ACTION="$1"
    local FILE="$2"
    local OPTION="$3"
    local VALUE="$4"

    case $ACTION in
        --set )
            if [ -z "$(roundcube_conf --get "$FILE" "$OPTION")" ]; then
                echo "\$config['$3'] = '$4';" >> "$2"
            else
                sed -i -r "s|^\\s*(\\\$config\\[['\"]$OPTION['\"]\\])\\s*=[^;]*;|\\1 = '$VALUE';|g" "$FILE"
            fi
        ;;
        --get )
            cat "$FILE" | grep -oP '(?<=\$config\['\'"$OPTION"\''\] = '\'').*(?='\'';)' | sed -r -e 's|^[^'\'']*'\''||g' -e 's|'\''.*$||'
        ;;
        --del )
            sed -i -r "/^\\s*(\\\$config\\[['\"]$OPTION['\"]\\])\\s*=[^;]*;/d" "$FILE"
    esac
}

function opendkim_conf {
    local ACTION="$1"
    local FILE="$2"
    local OPTION="$3"
    local VALUE="$4"

    case $ACTION in
        --set )
            sed -i '1{p;s|.*|'$OPTION' '"$VALUE"'|;h;d;};/^'$OPTION'/{g;p;s|.*||;h;d;};$G' $FILE
        ;;
    esac
}

function start_dirsrv {
    mkdir -p /var/run/dirsrv /var/lock/dirsrv/slapd-$(hostname -s)
    chown -R dirsrv:dirsrv /var/run/dirsrv /var/lock/dirsrv
    echo systemctl start dirsrv@$(hostname -s).service
    systemctl start dirsrv@$(hostname -s).service
}
