FROM kvaps/baseimage:systemd
MAINTAINER kvaps <kvapss@gmail.com>
ENV REFRESHED_AT 2016-10-19

# Install repositories
RUN yum -y update \
 && yum -y install epel-release \
 && yum -y install http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm \
 && curl -o /etc/yum.repos.d/Kolab:16.repo  http://obs.kolabsys.com/repositories/Kolab:/16/CentOS_7/Kolab:16.repo \
# Configure keys and priority
 && gpg --keyserver pool.sks-keyservers.net --recv-key 0x352c64e5 \
 && gpg --export --armor epel@fedoraproject.org > epel.asc \
 && rpm --import epel.asc \
 && rm -f epel.asc \
 && gpg --keyserver pool.sks-keyservers.net --recv-key 0x446D5A45 \
 && gpg --export --armor devel@lists.kolab.org > devel.asc \
 && rpm --import devel.asc \
 && rm -f devel.asc \
# Configure priority
 && yum -y install yum-plugin-priorities \
 && for f in /etc/yum.repos.d/Kolab*.repo; do echo "priority = 60" >> $f; done \
# Also install docfiles as they contain important files for the setup-kolab script
 && sed -i '/nodocs/d' /etc/yum.conf

RUN yum -y install expect vim crudini fail2ban php-fpm opendkim nginx mod_ssl anacron logrotate patch rsyslog clamav-update \
 && systemctl disable firewalld.service

# Install kolab
RUN yum -y install kolab manticore mongodb-server

# fix guam for cyrus-imapd waiting
RUN sed -i -e '/^\(Requires\|After\)=/ d' -e '/^Description=/aAfter=syslog.target cyrus-imapd.service\nRequires=cyrus-imapd.service' /usr/lib/systemd/system/guam.service

# fix manticore
RUN mkdir -p /etc/manticore/node_modules \
 && ln -s /usr/share/manticore/node_modules /etc/manticore/node_modules \
 && rm -f /etc/php-fpm.d/www.conf

#User for 389-ds
RUN groupadd -g 389 dirsrv ; useradd -u 389 -g 389 -c 'DS System User' -d '/var/lib/dirsrv' --no-create-home -s '/sbin/nologin' dirsrv

ADD bin/ /bin/
ADD etc/ /etc/
ADD lib/start/ /lib/start/

VOLUME ["/data", "/config", "/spool", "/log"]

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
#ENTRYPOINT ["/bin/start.sh"]

## Add config and setup script, run it
#ADD configs/nginx/letsencrypt.conf /etc/nginx/letsencrypt.conf
#ADD configs/nginx/kolab.conf /etc/nginx/kolab.conf
#ADD configs/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf
#RUN rm -f /etc/php-fpm.d/www.conf
#ADD configs/php-fpm.d/* /etc/php-fpm.d/
#ADD configs/fail2ban/jail.conf /etc/fail2ban/jail.conf
#ADD configs/fail2ban/filter.d/* /etc/fail2ban/filter.d/
#ADD start.sh /bin/start.sh
