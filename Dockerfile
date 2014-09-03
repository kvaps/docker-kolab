FROM centos:centos6
RUN mv /etc/localtime /etc/localtime.old; ln -s /usr/share/zoneinfo/Europe/Berlin /etc/localtime
RUN sed -i '/HOSTNAME/c\HOSTNAME=foo.bar.tld' /etc/sysconfig/network
RUN localedef -v -c -i en_US -f UTF-8 en_US.UTF-8; $(exit 0)
RUN localedef -v -c -i de_DE -f UTF-8 de_DE.UTF-8; $(exit 0)
ENV LANG de_DE.UTF-8

RUN yum -y update
RUN yum -y install wget yum-downloadonly
RUN rpm -Uhv http://ftp-stud.hs-esslingen.de/pub/epel/6/i386/epel-release-6-8.noarch.rpm
WORKDIR /etc/yum.repos.d
RUN wget http://obs.kolabsys.com:82/Kolab:/3.2/CentOS_6/Kolab:3.2.repo
RUN wget http://obs.kolabsys.com:82/Kolab:/3.2:/Updates/CentOS_6/Kolab:3.2:Updates.repo

RUN mkdir /root/packages
# Manually download packages, because /usr/share/doc contents are not installed for some reason
RUN yum --downloadonly --downloaddir=/root/packages --enablerepo=centosplus -y install kolab; $(exit 0)
# Install kolab
RUN yum --enablerepo=centosplus install -y kolab
# Extract downloaded packages and copy /usr/share/doc contents. They contain schema files needed
# by setup-kolab
WORKDIR /root/packages
RUN for i in *.rpm; do rpm2cpio $i | cpio -idmv; done
RUN cp -r /root/packages/usr/share/doc/* /usr/share/doc
WORKDIR /root
RUN rm -rf /root/packages

RUN touch /var/log/kolab/pykolab.log

# Set hostnames manually, because they are somehow wrong inside the container
RUN sed -i '/$myhostname = '"'host.example.com'"';/c\\\$myhostname = '"'foo.bar.tld';" /usr/share/kolab/templates/amavisd.conf.tpl
RUN sed -i -e '/myhostname = host.domain.tld/c\myhostname = foo.bar.tld' /etc/postfix/main.cf

# Install SSL packages
RUN yum -y install openssl mod_ssl

# Add domain certificates and CA
ADD domain.key /etc/pki/tls/private/domain.key
RUN chmod 600 /etc/pki/tls/private/domain.key
ADD domain.crt /etc/pki/tls/certs/domain.crt
ADD ca.pem /etc/pki/tls/certs/ca.pem

# Create certificate bundles
RUN cat /etc/pki/tls/certs/domain.crt /etc/pki/tls/private/domain.key /etc/pki/tls/certs/ca.pem > /etc/pki/tls/private/domain.bundle.pem
RUN cat /etc/pki/tls/certs/ca.pem > /etc/pki/tls/certs/domain.ca-chain.pem

# Add ssl group
RUN groupadd ssl
RUN usermod -a -G ssl cyrus
RUN chown -R root:ssl /etc/pki/tls/private
RUN chmod 750 /etc/pki/tls/private
RUN chmod 640 /etc/pki/tls/private/*

# Add CA to system’s CA bundle
RUN cat /etc/pki/tls/certs/ca.pem >> /etc/pki/tls/certs/ca-bundle.crt

ADD roundcubemailconfig.inc.php /root/roundcubemailconfig.inc.php

# Add start and stop scripts
ADD configure_ssl.sh /root/configure_ssl.sh
ADD start.sh /root/start.sh
ADD stop.sh /root/stop.sh

# Ports: SMTP, IMAP, HTTPS, SUBMISSION, SIEVE
EXPOSE 25 143 443 587 4190
