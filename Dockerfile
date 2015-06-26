FROM centos:centos6
MAINTAINER kvaps <kvapss@gmail.com>

RUN mv /etc/localtime /etc/localtime.old; ln -s /usr/share/zoneinfo/Europe/Moscow /etc/localtime
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

# Also install docfiles as they contain important files for the setup-kolab script
RUN sed -i '/nodocs/d' /etc/yum.conf

# Install kolab
RUN yum -y install kolab

# Install additional soft
RUN yum -y install supervisor expect mod_ssl nginx php-fpm opendkim fail2ban git php-devel zlib-devel gcc pcre-devel dhclient

#Update php-zlib
RUN pecl install zip

#Install zipdownload

RUN git clone https://github.com/roundcube/roundcubemail/ --depth 1 /tmp/roundcube
RUN mv /tmp/roundcube/plugins/zipdownload/ /usr/share/roundcubemail/plugins/
RUN rm -rf /tmp/roundcube/

#User for 389-ds
RUN adduser dirsrv

# fix bug: "unable to open Berkeley db /etc/sasldb2: No such file or directory"
RUN echo password | saslpasswd2 sasldb2 && chown cyrus:saslauth /etc/sasldb2

# fix: http://trac.roundcube.net/ticket/1490424
RUN sed -i "840s/\$this/\$me/g"  /usr/share/roundcubemail/program/lib/Roundcube/rcube_ldap.php 

# MySQL LDAP IMAP
VOLUME ["/data"]

WORKDIR /root

# Add config and setup script, run it
ADD wrappers/* /bin/
ADD settings.ini /etc/settings.ini
ADD setup.sh /bin/setup.sh
ENTRYPOINT ["/bin/setup.sh"]
 
# Ports: HTTP HTTPS SMTP SMTPS POP3 POP3S IMAP IMAPS SIEVE
EXPOSE  80 443 25 587 143 993 110 995 4190
