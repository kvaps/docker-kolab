FROM kvaps/baseimage:systemd
MAINTAINER kvaps <kvapss@gmail.com>
ENV REFRESHED_AT 2016-07-12

# Install repositories
RUN yum -y update \
 && yum -y install epel-release \
 && yum -y install http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm \
 && curl -o /etc/yum.repos.d/Kolab:16.repo  http://obs.kolabsys.com/repositories/Kolab:/16/CentOS_7/Kolab:16.repo \
# Configure keys and priority
 && gpg --keyserver pgp.mit.edu --recv-key 0x446D5A45 \
 && gpg --export --armor devel@lists.kolab.org > devel.asc \
 && rpm --import devel.asc \
 && rm -f devel.asc \
 && yum -y install yum-plugin-priorities \
 && for f in /etc/yum.repos.d/Kolab*.repo; do echo "priority = 60" >> $f; done \
# Also install docfiles as they contain important files for the setup-kolab script
 && sed -i '/nodocs/d' /etc/yum.conf

RUN yum -y install expect vim

# Install kolab
RUN yum -y install kolab

#User for 389-ds
RUN adduser dirsrv

ADD setup-kolab.exp /bin/setup-kolab.exp
ADD start.sh /bin/start.sh

## Install additional soft
#RUN yum -y install supervisor expect mod_ssl nginx php-fpm opendkim fail2ban git php-devel zlib-devel gcc pcre-devel dhclient
#
## Update php-zlib
#RUN pecl install zip
#
##Install zipdownload
#RUN git clone https://github.com/roundcube/roundcubemail/ --depth 1 /tmp/roundcube \
# && mv /tmp/roundcube/plugins/zipdownload/ /usr/share/roundcubemail/plugins/ \
# && rm -rf /tmp/roundcube/
#
#
## fix bug: "unable to open Berkeley db /etc/sasldb2: No such file or directory"
#RUN echo password | saslpasswd2 sasldb2 && chown cyrus:saslauth /etc/sasldb2
#
## fix: http://trac.roundcube.net/ticket/1490424
#RUN sed -i "840s/\$this/\$me/g"  /usr/share/roundcubemail/program/lib/Roundcube/rcube_ldap.php 
#
## fix permissions for amavis and clam
#RUN sed -i 's|"/var/spool/amavisd/clamd.sock"|"127.0.0.1:3310"|' /etc/amavisd/amavisd.conf \
# && usermod -a -G clam -G amavis clam \
# && usermod -a -G clam -G amavis amavis

# Ports: HTTP HTTPS SMTP SMTPS POP3 POP3S IMAP IMAPS SIEVE
#EXPOSE  80 443 25 587 143 993 110 995 4190
#VOLUME ["/data"]
#ENTRYPOINT ["/bin/start.sh"]

## Add config and setup script, run it
#ADD service-wrapper.sh /bin/service-wrapper.sh
#ADD set_spam_sieve.sh /bin/set_spam_sieve.sh
#ADD configs/supervisord.conf /etc/supervisord.conf
#ADD configs/nginx/letsencrypt.conf /etc/nginx/letsencrypt.conf
#ADD configs/nginx/kolab.conf /etc/nginx/kolab.conf
#ADD configs/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf
#RUN rm -f /etc/php-fpm.d/www.conf
#ADD configs/php-fpm.d/* /etc/php-fpm.d/
#ADD configs/fail2ban/jail.conf /etc/fail2ban/jail.conf
#ADD configs/fail2ban/filter.d/* /etc/fail2ban/filter.d/
#ADD start.sh /bin/start.sh
