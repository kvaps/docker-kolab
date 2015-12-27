Kolab 3.4 in a Docker
=====================

This is my version of the Kolab for docker.
Installation is supports automatic configuration **kolab**, **nginx**, **ssl**, **opendkim** and **fail2ban**

Quick start
-----------

Run command:
```bash
docker run \
    --name kolab \
    -h mail.example.org \
    -v /opt/kolab:/data:rw \
    -e TZ=Europe/Moscow \
    -e LDAP_ADMIN_PASS=<password> \
    -e LDAP_MANAGER_PASS=<password> \
    -e LDAP_CYRUS_PASS=<password> \
    -e LDAP_KOLAB_PASS=<password> \
    -e MYSQL_ROOT_PASS=<password> \
    -e MYSQL_KOLAB_PASS=<password> \
    -e MYSQL_ROUNDCUBE_PASS=<password> \
    -p 80:80 \
    -p 443:443 \
    -p 25:25 \
    -p 587:587 \
    -p 110:110 \
    -p 995:995 \
    -p 143:143 \
    -p 993:993 \
    -p 4190:4190 \
    --cap-add=NET_ADMIN \
    --entrypoint=/bin/bash \
    kvaps/kolab
```
It should be noted that the `--cap-add=NET_ADMIN` option is necessary only for **Fail2ban**, if you do not plan to use **Fail2ban**, you can exclude it.

You can also more integrate Kolab to your system, simply replace `-v` options like this:
```bash
    -v /etc/kolab:/data/etc:rw \
    -v /var/spool/kolab:/data/var/spool:rw \
    -v /var/lib/kolab:/data/var/lib:rw \
    -v /var/log/kolab:/data/var/log:rw \
```

Docker-compose
--------------

You can use the docker-compose for this image is really simplify your life:

```yaml
kolab:
  restart: always
  image: kvaps/kolab
  hostname: mail
  domainname: example.org
  volumes:
    - /etc/localtime:/etc/localtime:ro
    - ./kolab:/data:rw
  environment:
    - TZ=Europe/Moscow
    - LDAP_ADMIN_PASS=<password>
    - LDAP_MANAGER_PASS=<password>
    - LDAP_CYRUS_PASS=<password>
    - LDAP_KOLAB_PASS=<password>
    - MYSQL_ROOT_PASS=<password>
    - MYSQL_KOLAB_PASS=<password>
    - MYSQL_ROUNDCUBE_PASS=<password>
    - KOLAB_DEFAULT_LOCALE=ru_RU
    - ROUNDCUBE_SKIN=larry
  ports:
    - 80:80
    - 443:443
    - 25:25
    - 587:587
    - 110:110
    - 995:995
    - 143:143
    - 993:993
    - 4190:4190
    - 389:389
  cap_add:
    - NET_ADMIN
```

Configuration
-------------

#### SSL-certificates

Put your key and certificates to `/opt/kolab/etc/pki/tls/kolab`
Alternative you can use [kvaps/letsencrypt-webroot](https://github.com/kvaps/docker-letsencrypt-webroot) image, 
In this case, be sure to specify these options:
```bash
    -e 'CERT_PATH=/etc/letsencrypt/live'
    -e 'LE_RENEW_HOOK=docker restart @CONTAINER_NAME@' \
```
*Note: Nginx in this image is already configured for use `/tmp/letsencrypt` as directory for letsencrypt checks*

#### Available Configuration Parameters

*Please refer the docker run command options for the `--env-file` flag where you can specify all required environment variables in a single file. This will save you from writing a potentially long docker run command. Alternatively you can use docker-compose.*

Below is the complete list of available options that can be used to customize your kolab installation.

##### Basic options

  - **TZ**: Sets the timezone. Defaults to `UTC`.
  - **WEBSERVER**: Choose the backend. May be `apache` or `nginx`. Defaults to `nginx`.
  - **FORCE_HTTPS** Sets webserver for force redirect to https. Defaults to `false`.
  - **NGINX_CACHE** Enable nginx and fastcgi cacheing. Defaults to `false`.
  - **SPAM_SIEVE**: Sets the global sieve script to place mail marked as spam into Spam folder. Defaults to `true`.
  - **SPAM_SIEVE_TIMEOUT** : Sets how often to run a check of global sieve script for users. Defaults to `15m`.
  - **FAIL2BAN**: Enables Fail2Ban. Defaults to `true`.
  - **DKIM**: Enables DKIM signing. Defaults to `true`.
  - **CERT_PATH**: Path to the certificates. Defaults to `true`.

##### Set the passwords

By default passwords generates automatically and printing at the end of the installation script. You can specify the passwords you want to use.

  - **LDAP_ADMIN_PASS**: supply a password for the LDAP administrator user 'admin', used to login to the graphical console of 389 Directory server. Defaults to `random`.
  - **LDAP_MANAGER_PASS**: supply a password for the LDAP Directory Manager user, which is the administrator user you will be using to at least initially log in to the Web Admin, and that Kolab uses to perform administrative tasks. Defaults to `random`.
  - **LDAP_CYRUS_PASS**: supply a Cyrus Administrator password. This password is used by Kolab to execute administrative tasks in Cyrus IMAP. You may also need the password yourself to troubleshoot Cyrus IMAP and/or perform other administrative tasks against Cyrus IMAP directly. Defaults to `random`.
  - **LDAP_KOLAB_PASS**: supply a Kolab Service account password. This account is used by various services such as Postfix, and Roundcube, as anonymous binds to the LDAP server will not be allowed. Defaults to `random`.
  - **MYSQL_ROOT_PASS**: supply the root password for MySQL, so we can set up user accounts for other components that use MySQL. Defaults to `random`.
  - **MYSQL_KOLAB_PASS**: supply a password for the MySQL user 'kolab'. This password will be used by Kolab services, such as the Web Administration Panel. Defaults to `random`.
  - **MYSQL_ROUNDCUBE_PASS**: supply a password for the MySQL user 'roundcube'. This password will be used by the Roundcube webmail interface. Defaults to `random`.

##### Advanced configuration

  - **KOLAB_RCPT_POLICY**: Enables the Recipient policy. Defaults to `false`.
  - **KOLAB_DEFAULT_LOCALE**: Sets default locale for Kolab. Defaults to `en_US`.
  - **MAX_MEMORY_SIZE**: Sets the maximum memory size for php. Defaults to `256M`.
  - **MAX_FILE_SIZE**: Sets the max upload size. Defaults to `30M`.
  - **MAX_MAIL_SIZE**: Sets the max letter size. Defaults to `30M`.
  - **MAX_BODY_SIZE**: Sets the the max body size for nginx. Defaults to `50M`.
  - **ROUNDCUBE_SKIN**: Sets the skin for roundcube, may be `larry` or `chameleon`. Defaults to `chameleon`.
  - **ROUNDCUBE_ZIPDOWNLOAD**: Enables zipdownload plugin. Defaults to `true`.
  - **ROUNDCUBE_TRASH**: Sets how delete mails. May be `flag` or `trash`. Defaults to `trash`.

##### Configuring another milter,

This settings disables amavis with clamd and configures another milter

  - **EXT_MILTER_ADDR**: Sets the milter address and port. Example to `inet:rmilter:11339`.
  - **EXT_MILTER_PROTO**: Sets the milter protocol. Defaults to `4`.

Multi-instances
---------------

I use [pipework](https://hub.docker.com/r/dreamcat4/pipework/) image for passthrough external ethernet cards into docker container.

See [examples](https://github.com/dreamcat4/docker-images/blob/master/pipework/3.%20Examples.md), that's realy simple!

Update notes
------------

For update from previous versions of my docker image, please follow these simple steps:

  - Run container with `--entrypoint=/bin/bash` option:
```bash
docker run \
    -v /opt/kolab:/data:rw \
    -ti --rm\
    --entrypoint=/bin/bash \
    kvaps/kolab
```

  - Update supervisord config:
```bash

# Сheck which services is startup (not commented)
cat /data/etc/supervisord.conf
# Make the same
vi /etc/supervisord.conf
# Replace your file with a new
cp -f /etc/supervisord.conf /data/etc/supervisord.conf
```

  - If you have not default.bc script:

```bash
# Create default sieve script
mkdir -p /data/var/lib/imap/sieve/global/
cat > /data/var/lib/imap/sieve/global/default.script << EOF
require "fileinto";
if header :contains "X-Spam-Flag" "YES"
{
        fileinto "Spam";
}
EOF
# Compile it
/usr/lib/cyrus-imapd/sievec /data/var/lib/imap/sieve/global/default.script /data/var/lib/imap/sieve/global/default.bc
```
