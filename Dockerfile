FROM kvaps/baseimage:systemd
MAINTAINER kvaps <kvapss@gmail.com>
ENV REFRESHED_AT 2017-01-30

# Ports: HTTP HTTPS SMTP SMTPS POP3 POP3S IMAP IMAPS SIEVE
EXPOSE  80 443 25 587 143 993 110 995 4190
VOLUME ["/data", "/config", "/spool", "/log"]

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
RUN yum -y install kolab manticore mongodb-server \
 && echo "LC_ALL=C" >> /etc/sysconfig/mongod \
 && sed 's/^#smallfiles/smallfiles/' /etc/mongod.conf

# fix guam for cyrus-imapd waiting
RUN sed -i -e '/^\(Requires\|After\)=/ d' -e '/^Description=/aAfter=syslog.target cyrus-imapd.service\nRequires=cyrus-imapd.service' /usr/lib/systemd/system/guam.service

# fix manticore
RUN mkdir -p /etc/manticore/node_modules \
 && ln -s /usr/share/manticore/node_modules /etc/manticore/node_modules \
 && rm -f /etc/php-fpm.d/www.conf

ADD bin/ /bin/
ADD etc/ /etc/
ADD lib/start/ /lib/start/
