Kolab 3.4 in a Docker container
===============================

This is my version of the Kolab for docker.
Installation is supports automatic configuration **kolab**, **nginx**, **ssl**, **opendkim**, **amavis** and **fail2ban**

Run
---

```bash
docker run \
    --name kolab \
    -h mail.example.org \
    -v /opt/kolab:/data:rw \
    --env TZ=Europe/Moscow
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
    -ti \
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

If it is the first run, you will see the settings page, make your changes and save it, installation will continue...
*(You need to have the base knowledge of the [vi editor](http://google.com/#q=vi+editor))*

Configuration
-------------

### SSL-certificates

```bash

# Go to tls folder of your container
cd /opt/kolab/etc/pki/tls

# Set the variable with your kolab hostname
KOLAB_HOSTNAME='mail.example.org'

# Write your keys
vim private/${KOLAB_HOSTNAME}.key
vim certs/${KOLAB_HOSTNAME}.crt
vim certs/${KOLAB_HOSTNAME}-ca.pem

# Create certificate bundles
cat certs/${KOLAB_HOSTNAME}.crt private/${KOLAB_HOSTNAME}.key certs/${KOLAB_HOSTNAME}-ca.pem > private/${KOLAB_HOSTNAME}.bundle.pem
cat certs/${KOLAB_HOSTNAME}.crt certs/${KOLAB_HOSTNAME}-ca.pem > certs/${KOLAB_HOSTNAME}.bundle.pem
cat certs/${KOLAB_HOSTNAME}-ca.pem > certs/${KOLAB_HOSTNAME}.ca-chain.pem

# Set access rights
chown -R root:mail private
chmod 750 private
chmod 640 private/*

# Add CA to system’s CA bundle
cat certs/${KOLAB_HOSTNAME}-ca.pem >> certs/ca-bundle.crt
```

### Available Configuration Parameters

*Please refer the docker run command options for the `--env-file` flag where you can specify all required environment variables in a single file. This will save you from writing a potentially long docker run command. Alternatively you can use docker-compose.*

Below is the complete list of available options that can be used to customize your kolab installation.

#### Basic options

  - **TZ**: Sets the timezone. Defaults to `UTC`.
  - **WEBSERVER**: Choose the backend. May be `apache` or `nginx`. Defaults to `nginx`.
  - **APACHE_HTTPS** Sets apache for force redirect to https. Defaults to `true`.
  - **NGINX_CACHE** Enable nginx and fastcgi cacheing. Defaults to `false`.
  - **SPAM_SIEVE**: Sets the global sieve script to place mail marked as spam into Spam folder. Defaults to `true`.
  - **FAIL2BAN**: Enables Fail2Ban. Defaults to `true`.
  - **DKIM**: Enables DKIM signing. Defaults to `true`.

#### Set the passwords

By default passwords generates automatically and printing at the end of the installation script. You can specify the passwords you want to use.

  - **LDAP_ADMIN_PASS**: supply a password for the LDAP administrator user 'admin', used to login to the graphical console of 389 Directory server. Defaults to `random`.
  - **LDAP_MANAGER_PASS**: supply a password for the LDAP Directory Manager user, which is the administrator user you will be using to at least initially log in to the Web Admin, and that Kolab uses to perform administrative tasks. Defaults to `random`.
  - **LDAP_CYRUS_PASS**: supply a Cyrus Administrator password. This password is used by Kolab to execute administrative tasks in Cyrus IMAP. You may also need the password yourself to troubleshoot Cyrus IMAP and/or perform other administrative tasks against Cyrus IMAP directly. Defaults to `random`.
  - **LDAP_KOLAB_PASS**: supply a Kolab Service account password. This account is used by various services such as Postfix, and Roundcube, as anonymous binds to the LDAP server will not be allowed. Defaults to `random`.
  - **MYSQL_ROOT_PASS**: supply the root password for MySQL, so we can set up user accounts for other components that use MySQL. Defaults to `random`.
  - **MYSQL_KOLAB_PASS**: supply a password for the MySQL user 'kolab'. This password will be used by Kolab services, such as the Web Administration Panel. Defaults to `random`.
  - **MYSQL_ROUNDCUBE_PASS**: supply a password for the MySQL user 'roundcube'. This password will be used by the Roundcube webmail interface. Defaults to `random`.

#### Advanced configuration

  - **KOLAB_RCPT_POLICY**: Enables the Recipient policy. Defaults to `false`.
  - **KOLAB_DEFAULT_LOCALE**: Sets default locale for Kolab. Defaults to `en_US`.
  - **MAX_MEMORY_SIZE**: Sets the maximum memory size for php. Defaults to `256M`.
  - **MAX_FILE_SIZE**: Sets the max upload size. Defaults to `30M`.
  - **MAX_MAIL_SIZE**: Sets the max letter size. Defaults to `30M`.
  - **MAX_BODY_SIZE**: Sets the the max body size for nginx. Defaults to `50M`.
  - **ROUNDCUBE_SKIN**: Sets the skin for roundcube, may be `larry` or `chameleon`. Defaults to `chameleon`.
  - **ROUNDCUBE_ZIPDOWNLOAD**: Enables zipdownload plugin. Defaults to `true`.
  - **ROUNDCUBE_TRASH**: Sets how delete mails. May be `flag` or `trash`. Defaults to `trash`.

#### Configuring another milter,

This settings disables amavis with clamd and configures another milter

  - **EXT_MILTER_ADDR**: Sets the milter address and port. Example to `inet:rmilter:11339`.
  - **EXT_MILTER_PROTO**: Sets the milter protocol. Defaults to `4`.

Systemd unit
------------

You can create a unit for systemd, which would run it as a service and use when startup

```bash
vi /etc/systemd/system/kolab.service
```

```ini
[Unit]
Description=Kolab Groupware
After=docker.service
Requires=docker.service

[Service]
Restart=always
ExecStart=/usr/bin/docker start -a kolab
ExecStop=/usr/bin/docker stop kolab

[Install]
WantedBy=multi-user.target
```

Now you can activate and start the container:
```bash
systemctl enable kolab
systemctl start kolab
```



Multi-instances
---------------

I use [pipework](https://github.com/jpetazzo/pipework) script for passthrough external ethernet cards into docker container

I write such systemd-unit:
```bash
vi /etc/systemd/system/kolab@.service
```
```ini
[Unit]
Description=Kolab Groupware for %I
After=docker.service
Requires=docker.service

[Service]
EnvironmentFile=/etc/kolab-docker/%i
Restart=always

ExecStart=/bin/bash -c 'docker run --name ${DOCKER_NAME} -h ${DOCKER_HOSTNAME} -v ${DOCKER_VOLUME}:/data:rw ${DOCKER_OPTIONS} kvaps/kolab'
ExecStartPost=/bin/bash -c ' \
        pipework ${EXT_INTERFACE} -i eth1 ${DOCKER_NAME} ${EXT_ADDRESS}@${EXT_GATEWAY}; \
        docker exec ${DOCKER_NAME} bash -c "${INT_ROUTE}"; \
        docker exec ${DOCKER_NAME} bash -c "if ! [ \"${DNS_SERVER}\" = \"\" ] ; then echo nameserver ${DNS_SERVER} > /etc/resolv.conf ; fi" '

ExecStop=/bin/bash -c 'docker stop -t 2 ${DOCKER_NAME} ; docker rm -f ${DOCKER_NAME}'

[Install]
WantedBy=multi-user.target
```

And this config for each instance:
```bash
vi /etc/kolab-docker/example.org
```
```bash
DOCKER_HOSTNAME=mail.example.org
DOCKER_NAME="kolab-$(echo $DOCKER_HOSTNAME | cut -d. -f 2-)"
DOCKER_VOLUME="/opt/kolab-$(echo $DOCKER_HOSTNAME | cut -d. -f 2-)"
DOCKER_OPTIONS='--env TZ=Europe/Moscow --cap-add=NET_ADMIN --link rmilter:rmilter -p 25:25 -p 389:389'
 
EXT_INTERFACE=eth2
#EXT_ADDRESS='dhclient D2:84:9D:CA:F3:BC'
EXT_ADDRESS='10.10.10.123/24'
EXT_GATEWAY='10.10.10.1'
DNS_SERVER='8.8.8.8'
 
INT_ROUTE='ip route add 192.168.1.0/24 via 172.17.42.1 dev eth0'
```
Just simple use:
```bash
systemctl enable kolab@example.org
systemctl start kolab@example.org
```

For setup and manage container, can use [kolab-worker.sh](https://github.com/kvaps/docker-kolab/blob/master/kolab-worker.sh) script
