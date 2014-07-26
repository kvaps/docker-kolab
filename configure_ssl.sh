#!/bin/bash
#Configure Apache for SSL
sed -i -e '/SSLCertificateFile \/etc\/pki/c\SSLCertificateFile /etc/pki/tls/certs/domain.crt' /etc/httpd/conf.d/ssl.conf
sed -i -e '/SSLCertificateKeyFile \/etc\/pki/c\SSLCertificateKeyFile /etc/pki/tls/private/domain.key' /etc/httpd/conf.d/ssl.conf
sed -i -e '/SSLCertificateChainFile \/etc\/pki/c\SSLCertificateChainFile /etc/pki/tls/certs/domain.ca-chain.pem' /etc/httpd/conf.d/ssl.conf

#Configure Cyrus for SSL
sed -r -i -e 's|^tls_cert_file:.*|tls_cert_file: /etc/pki/tls/certs/domain.crt|g' -e 's|^tls_key_file:.*|tls_key_file: /etc/pki/tls/private/domain.key|g' -e 's|^tls_ca_file:.*|tls_ca_file: /etc/pki/tls/certs/domain.ca-chain.pem|g' /etc/imapd.conf

#Configure Postfix for SSL
postconf -e smtpd_tls_key_file=/etc/pki/tls/private/domain.key
postconf -e smtpd_tls_cert_file=/etc/pki/tls/certs/domain.crt
postconf -e smtpd_tls_CAfile=/etc/pki/tls/certs/domain.ca-chain.pem

#Configure Roundcube for SSL
sed -i -e '/kolab_ssl/d' /etc/roundcubemail/libkolab.inc.php
sed -i -e 's/http:/https:/' /etc/roundcubemail/kolab_files.inc.php
sed -i -e '/^?>/d' /etc/roundcubemail/config.inc.php
cat < /root/roundcubemailconfig.inc.php >> /etc/roundcubemail/config.inc.php
