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
RUN yum -y install expect mod_ssl nginx php-fpm opendkim fail2ban 

# Add domain certificates and CA
ADD certs /root/certs

WORKDIR /root

# Add start and stop scripts
ADD start.sh /root/start.sh
ADD stop.sh /root/stop.sh

# Add config and setup script, run it
ADD settings.ini /root/settings.ini
ADD setup.sh /root/setup.sh
RUN /root/setup.sh
 
# Ports: SMTP, IMAP, HTTPS, SUBMISSION, SIEVE
EXPOSE  25 80 143 443 587 4190
