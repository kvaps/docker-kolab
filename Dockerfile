FROM centos:centos6
ADD hostname /root/hostname

RUN mv /etc/localtime /etc/localtime.old; ln -s /usr/share/zoneinfo/Europe/Moscow /etc/localtime
RUN sed -i "/HOSTNAME/c\HOSTNAME=`cat /root/hostname`" /etc/sysconfig/network
RUN localedef -v -c -i en_US -f UTF-8 en_US.UTF-8; $(exit 0)
#RUN localedef -v -c -i ru_RU -f UTF-8 ru_RU.UTF-8; $(exit 0)
ENV LANG en_US.UTF-8

RUN yum -y update
RUN yum -y install wget epel-release 
WORKDIR /etc/yum.repos.d
RUN wget http://obs.kolabsys.com/repositories/Kolab:/3.4/CentOS_6/Kolab:3.4.repo
RUN wget http://obs.kolabsys.com/repositories/Kolab:/3.4:/Updates/CentOS_6/Kolab:3.4:Updates.repo


RUN gpg --keyserver pgp.mit.edu --recv-key 0x446D5A45
RUN gpg --export --armor devel@lists.kolab.org > devel.asc
RUN rpm --import devel.asc
RUN rm devel.asc

RUN yum -y install kolab

# Set hostnames manually, because they are somehow wrong inside the container
#RUN sed -i '/$myhostname = '"'host.example.com'"';/c\\\$myhostname = '"'`cat /root/hostname`';" /usr/share/kolab/templates/amavisd.conf.tpl
#RUN sed -i -e "/myhostname = host.domain.tld/c\myhostname = `cat /root/hostname`" /etc/postfix/main.cf

# Add domain certificates and CA
#ADD domain.key /etc/pki/tls/private/domain.key
#RUN chmod 600 /etc/pki/tls/private/domain.key
#ADD domain.crt /etc/pki/tls/certs/domain.crt
#ADD ca.pem /etc/pki/tls/certs/ca.pem
 
# Create certificate bundles
#RUN cat /etc/pki/tls/certs/domain.crt /etc/pki/tls/private/domain.key /etc/pki/tls/certs/ca.pem > /etc/pki/tls/private/domain.bundle.pem
#RUN cat /etc/pki/tls/certs/ca.pem > /etc/pki/tls/certs/domain.ca-chain.pem
 
# Set access rights
#RUN chown -R root:mail /etc/pki/tls/private
#RUN chmod 750 /etc/pki/tls/private
#RUN chmod 640 /etc/pki/tls/private/*
 
# Add CA to system’s CA bundle
#RUN cat /etc/pki/tls/certs/ca.pem >> /etc/pki/tls/certs/ca-bundle.crt
# 
# Add SSL postconfig files
#ADD configure_ssl.sh /root/configure_ssl.sh
#ADD roundcubemailconfig.inc.php /root/roundcubemailconfig.inc.php
# 
# Add start and stop scripts
#ADD start.sh /root/start.sh
#ADD stop.sh /root/stop.sh
# 
# Ports: SMTP, IMAP, HTTPS, SUBMISSION, SIEVE
#EXPOSE 25 143 443 587 4190
