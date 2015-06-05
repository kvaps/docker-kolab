#!/bin/bash

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
    old_hostname="$(cat /etc/hostname)"
    new_hostname="$(echo $main_hostname | cut -d. -f1)"
    new_domain="$(echo $main_hostname | cut -d. -f2-)"
    echo $main_hostname > /etc/hostname
    sed -e "s/$old_hostname/$main_hostname\ $new_hostname/g" /etc/hosts | tee /etc/hosts
}

configure_kolab()
{
if [[ $main_configure_kolab == "true" ]]
    set_hostname
then
    adduser dirsrv
    expect <<EOF
    spawn   setup-kolab --fqdn=$main_hostname --timezone=$kolab_Timezone_ID'
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
    expect  "MySQL roundcube password *:"
    send    "$kolab_MySQL_root_password\r"
    expect  "Confirm MySQL roundcube password:"
    send    "$kolab_MySQL_root_password\r"
    expect  "Cyrus Administrator password *:"
    send    "$kolab_Cyrus_Administrator_password\r"
    expect  "Confirm Cyrus Administrator password:"
    send    "$kolab_Cyrus_Administrator_password\r"
    expect  "Starting kolabd:"
    exit    0
EOF
fi
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

get_config settings.ini
configure_kolab
#set_hostname

