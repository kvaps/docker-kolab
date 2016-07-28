#!/bin/bash

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

    configure_${VARIABLE,,} ${STATE} || ( >&2 echo "configure: Error executing configure_${VARIABLE,,} ${STATE}" ; exit 1)
}

# Main functions

function setup_kolab {
    chk_env LDAP_ADMIN_PASS
    chk_env LDAP_MANAGER_PASS
    chk_env LDAP_CYRUS_PASS
    chk_env LDAP_KOLAB_PASS
    chk_env MYSQL_ROOT_PASS
    chk_env MYSQL_KOLAB_PASS
    chk_env MYSQL_ROUNDCUBE_PASS

    setup_kolab.exp

    # Redirect to /webmail/ in apache
    sed -i 's/^\(DocumentRoot \).*/\1"\/usr\/share\/roundcubemail\/public_html"/' /etc/httpd/conf/httpd.conf
}

function configure_webserver {
    case $1 in
        nginx  ) 
            # Manage services
            export SERVICE_HTTPD=true
            export SERVICE_NGINX=false
            export SERVICE_PHP_FPM=false

            # Conigure Kolab for nginx
            sed -i '/^\[kolab_wap\]/,/^\[/ { x; /^$/ !{ x; H }; /^$/ { x; h; }; d; }; x; /^\[kolab_wap\]/ { s/\(\n\+[^\n]*\)$/\napi_url = https:\/\/'$(hostname -f)'\/kolab-webadmin\/api\1/; p; x; p; x; d }; x' /etc/kolab/kolab.conf
            # TODO: add https://docs.kolab.org/howtos/nginx-webserver.html#finalize-common
        ;;
        apache )
            # Manage services
            export SERVICE_HTTPD=false
            export SERVICE_NGINX=true
            export SERVICE_PHP_FPM=true

            # Conigure Kolab for apache
            # TODO: add section
        ;;
    esac
}

function configure_force_https {
    case $1 in
        true  ) 

        ;;
        false )

        ;;
    esac
}

function configure_nginx_cache {
    case $1 in
        true  ) 

        ;;
        false )

        ;;
    esac
}

function configure_spam_sieve {
    case $1 in
        true  ) 
            # Manage services
            export SERVICE_SET_SPAM_SIEVE=true

            # Configure amavis
            sed -i '/^[^#]*$sa_spam_subject_tag/s/^/#/' /etc/amavisd/amavisd.conf
            sed -i 's/^\($final_spam_destiny.*= \).*/\1D_PASS;/' /etc/amavisd/amavisd.conf
            sed -r -i "s/^\\\$mydomain = '[^']*';/\\\$mydomain = '$(hostname -d)';/" /etc/amavisd/amavisd.conf
        ;;
        false )
            # Manage services
            export SERVICE_SET_SPAM_SIEVE=false

            # Configure amavis
            sed -i '/^#i.*$sa_spam_subject_tag/s/^#//' /etc/amavisd/amavisd.conf
            sed -i 's/^\($final_spam_destiny.*= \).*/\1D_DISCARD;/' /etc/amavisd/amavisd.conf
        ;;
    esac
}

function configure_fail2ban {
    case $1 in
        true  ) 
            # Manage services
            export SERVICE_FAIL2BAN=true

            # Configure OpenDKIM
            echo "info:  start configuring OpenDKIM"
        
            if [ ! -f "/etc/opendkim/keys/$(hostname -s).private" ] 
                opendkim-genkey -D /etc/opendkim/keys/ -d $(hostname -d) -s $(hostname -s)
                chgrp opendkim /etc/opendkim/keys/*
                chmod g+r /etc/opendkim/keys/*
            fi
            
            # TODO: Check this
            sed -i "/^127\.0\.0\.1\:[10025|10027].*smtpd/a \    -o receive_override_options=no_milters" /etc/postfix/master.cf

            # TODO: And this
            sed -i --follow-symlinks 's/^\(^Mode\).*/\1  sv/' /etc/opendkim.conf
            echo "KeyTable      /etc/opendkim/KeyTable" >> /etc/opendkim.conf
            echo "SigningTable  /etc/opendkim/SigningTable" >> /etc/opendkim.conf
            echo "X-Header yes" >> /etc/opendkim.conf
        
            echo $(hostname -f | sed s/\\./._domainkey./) $(hostname -d):$(hostname -s):$(ls /etc/opendkim/keys/*.private) | cat > /etc/opendkim/KeyTable
            echo $(hostname -d) $(echo $(hostname -f) | sed s/\\./._domainkey./) | cat > /etc/opendkim/SigningTable
        
            postconf -e milter_default_action=accept
            postconf -e milter_protocol=2
            postconf -e smtpd_milters=inet:localhost:8891
            postconf -e non_smtpd_milters=inet:localhost:8891
       ;;
       false )
           # Manage services
           export SERVICE_FAIL2BAN=false
           # Configure OpenDKIM
           # TODO: Add section
       ;;
    esac
}

function configure_dkim {
    case $1 in
        true  ) 

        ;;
        false )

        ;;
    esac
}

function configure_cert_path {
    if [ `find $CERT_PATH -prune -empty` ] ; then
        echo "configure_cert_path:  no certificates found in $CERT_PATH fallback to /etc/pki/tls/kolab"
        export CERT_PATH="/etc/pki/tls/kolab"
        domain_cers=${CERT_PATH}/$(hostname -f)
    else
        domain_cers=`ls -d ${CERT_PATH}/* | awk '{print $1}'`
    fi

    certificate_path=${domain_cers}/cert.pem
    privkey_path=${domain_cers}/privkey.pem
    chain_path=${domain_cers}/chain.pem
    fullchain_path=${domain_cers}/fullchain.pem

    if [ ! -f "$certificate_path" ] || [ ! -f "$privkey_path" ] ; then
        echo "info:  start generating certificate"
        mkdir -p ${domain_cers}

        # Generate key and certificate
        openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 \
                    -subj "/CN=$(hostname -f)" \
                    -keyout $privkey_path \
                    -out $certificate_path
    
        # Set access rights
        chown -R root:mail ${domain_cers}
        chmod 750 ${domain_cers}
        chmod 640 ${domain_cers}/*

        echo "info:  generating certificate finished"
    fi
    
    # Configure apache for SSL
    sed -i -e "/[^#]SSLCertificateFile /c\SSLCertificateFile $certificate_path" /etc/httpd/conf.d/ssl.conf
    sed -i -e "/[^#]SSLCertificateKeyFile /c\SSLCertificateKeyFile $privkey_path" /etc/httpd/conf.d/ssl.conf
    if [ -f "$chain_path" ]; then
        if `sed 's/#.*$//g' /etc/httpd/conf.d/ssl.conf | grep -q SSLCertificateChainFile` ; then
            sed -e "/[^#]*SSLCertificateChainFile: /cSSLCertificateChainFile: $chain_path" /etc/httpd/conf.d/ssl.conf
        else
            sed -i -e "/[^#]*SSLCertificateFile/aSSLCertificateChainFile: $chain_path" /etc/httpd/conf.d/ssl.conf 
        fi
    else
        sed -i -e "/SSLCertificateChainFile/d" /etc/httpd/conf.d/ssl.conf
    fi
    
    # Configuration nginx for SSL
    if [ -f "$fullchain_path" ]; then
        sed -i -e "/ssl_certificate /c\    ssl_certificate $fullchain_path;" /etc/nginx/conf.d/default.conf
    else
        sed -i -e "/ssl_certificate /c\    ssl_certificate $certificate_path;" /etc/nginx/conf.d/default.conf
    fi
    sed -i -e "/ssl_certificate_key/c\    ssl_certificate_key $privkey_path;" /etc/nginx/conf.d/default.conf
    
    #Configure Cyrus for SSL
    sed -r -i --follow-symlinks \
        -e "s|^tls_server_cert:.*|tls_server_cert: $certificate_path|g" \
        -e "s|^tls_server_key:.*|tls_server_key: $privkey_path|g" \
        /etc/imapd.conf

    if [ -f "$chain_path" ]; then
        if grep -q tls_server_ca_file /etc/imapd.conf ; then
            sed -i --follow-symlinks -e "s|^tls_server_ca_file:.*|tls_server_ca_file: $chain_path|g" /etc/imapd.conf
        else
            sed -i --follow-symlinks -e "/tls_server_cert/atls_server_ca_file: $chain_path" /etc/imapd.conf
        fi
    else
        sed -i --follow-symlinks -e "/^tls_server_ca_file/d" /etc/httpd/conf.d/ssl.conf
    fi
        
    #Configure Postfix for SSL
    postconf -e smtpd_tls_key_file=$privkey_path
    postconf -e smtpd_tls_cert_file=$certificate_path
    if [ -f "$chain_path" ]; then
        postconf -e smtpd_tls_CAfile=$chain_path
    else
        postconf -e smtpd_tls_CAfile=
    fi
}

function configure_kolab_default_locale {
    sed -i -e '/default_locale/c\default_locale = '$KOLAB_DEFAULT_LOCALE /etc/kolab/kolab.conf
}

function configure_max_memory_size {
    sed -i --follow-symlinks -e '/memory_limit/c\memory_limit = '$MAX_MEMORY_SIZE /etc/php.ini
}

function configure_max_file_size {
    sed -i --follow-symlinks -e '/upload_max_filesize/c\upload_max_filesize = '$MAX_FILE_SIZE /etc/php.ini
}

function configure_max_mail_size {
    sed -i --follow-symlinks -e '/post_max_size/c\post_max_size = '$MAX_MAIL_SIZE /etc/php.ini
    # Convert megabytes to bytes for postfix
    if [[ $MAX_MAIL_SIZE == *"M" ]] ; then MAX_MAIL_SIZE=$[($(echo $MAX_MAIL_SIZE | sed 's/[^0-9]//g'))*1024*1024] ; fi
    postconf -e message_size_limit=$MAX_MAIL_SIZE
}

function configure_max_mailbox_size {
    # Convert megabytes to bytes for postfix
    if [[ $MAX_MAILBOX_SIZE == *"M" ]] ; then MAX_MAILBOX_SIZE=$[($(echo $MAX_MAILBOX_SIZE | sed 's/[^0-9]//g'))*1024*1024] ; fi
    postconf -e mailbox_size_limit=$MAX_MAILBOX_SIZE
}

function configure_max_body_size {
    sed -i -e '/client_max_body_size/c\        client_max_body_size '$MAX_BODY_SIZE';' /etc/nginx/conf.d/default.conf 
}

function configure_roundcube_skin {
    sed -i -r "s/^\\s*(\\\$config\\[['\"]skin['\"]\\])\\s*=[^;]*;/\\1 = '${ROUNDCUBE_SKIN}';/g" /etc/roundcubemail/config.inc.php
}

function configure_roundcube_trash {
    case $1 in
        trash )
            sed -i "s/\$config\['skip_deleted'\] = '.*';/\$config\['skip_deleted'\] = 'false';/g" /etc/roundcubemail/config.inc.php
            sed -i "s/\$config\['flag_for_deletion'\] = '.*';/\$config\['flag_for_deletion'\] = 'false';/g" /etc/roundcubemail/config.inc.php
        ;;
        flag )
            sed -i "s/\$config\['skip_deleted'\] = '.*';/\$config\['skip_deleted'\] = 'true';/g" /etc/roundcubemail/config.inc.php
            sed -i "s/\$config\['flag_for_deletion'\] = '.*';/\$config\['flag_for_deletion'\] = 'true';/g" /etc/roundcubemail/config.inc.php
        ;;
}

function configure_ext_milter_addr {
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

        configure_roundcube_plugin $plugin_name $plugin_state
    done
}

# Addition functions

function configure_roundcube_plugin {
    local PLUGIN=$1
    local STATE=$2
    case $STATE in
        true  ) echo enable $PLUGIN ;;
        false ) echo disable $PLUGIN ;;
    esac
}
