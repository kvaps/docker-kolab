# Install Kolab 3.2 in a Docker container

This guide shows you how to set up Kolab 3.2 in a Docker container. I use this setup for my family, but it might also work for a small business.

This guide is partly based on the following guides:

http://kolab.org/blog/timotheus-pokorra/2014/03/26/building-docker-container-kolab-jiffybox

http://kolab.org/blog/staffe/2014/06/05/mit-dem-eigenen-vpsroot-server-weg-von-google-centos-6.5-kolab-3.2-owncloud-6

## Build the Kolab container

**For all instructions: Replace host.mydomain.tld with the FQDN of your server**

Put the right domain names in your files:
```bash
sed -i -e 's/foo.bar.tld/host.mydomain.tld/g' Dockerfile roundcubemailconfig.inc.php
```

Copy your SSL certificates into your build directory and name them as follows:

`domain.crt` Your signed certificate

`domain.key` Your private key

`ca.pem` Certificate of the CA that signed your certificate


Before you start the build process you might want to change time zone and locale in the `Dockerfile`, by default they are set to `Europe/Berlin` and `de_DE.UTF-8`.

Then build the container with (use whatever username you want as you will not upload any of the images created here because they contain your SSL keys):
```bash
docker build -t dockerusername/kolab:v1 .
```

## Set up the Kolab server
Create the container and attach:
```bash
docker run --name kolab -p 25:25 -p 143:143 -p 443:443 -p 587:587 -p 4190:4190 -h host.mydomain.tld -d -t -i dockerusername/kolab:v1 /bin/bash
docker attach kolab
```

In the container run:
```bash
setup-kolab
/root/stop.sh
/root/configure_ssl.sh
exit
```

Then restart the container and re-attach:
```bash
docker start kolab
docker attach kolab
```

If your server only has 1GB of RAM (like mine), you might want to disable virus detection by uncommenting the following line in `/etc/amavisd/amavisd.conf` (in the container)
```
@bypass_virus_checks_maps = (1);  # controls running of anti-virus code
```

You also need to change `/root/start.sh` and comment out:
```
#service clamd start
```


Then start your services:
```bash
/root/start.sh
```

The server should now be up and running and you can continue creating users on the kolab webadmin page
https://host.mydomain.tld/kolab-webadmin (log in with user name `cn=Directory Manager` and the password defined when running `setup-kolab`)

Afterwards you can log in to roundcubemail on:
https://host.mydomain.tld/roundcubemail

## Change default addresses
If you run the Kolab server for your family as I do, you might want to have email addresses like firstname@lastname.tld. You can achieve this by changing some default settings in `/etc/kolab/kolab.conf`:

In the section [mydomain.tld] change primary mail to:
```
primary_mail = %(givenname)s@%(domain)s
```

In section [kolab] change secondary mail to:
```
secondary_mail = {
        0: {
        "{0}@{1}": "format('%(uid)s', '%(domain)s')"
        },
        1: {
        "{0}@{1}": "format('%(givenname)s.%(surname)s', '%(domain)s')"
        }
        }
```

In section [kolab] change primary_mail to:
```
primary_mail = %(givenname)s@%(domain)s
```

In section [kolab] change policy_uid to:
```
policy_uid = %(givenname)s.lower()
```

In section [kolab] you can also change the default locale:
```
default_locale = de_DE
```

Restart the kolab service to apply the changes:
```bash
service kolabd restart
```

## Catch-all addresses for subdomains
If you want to have catch-all addresses for subdomains, you can use the following steps:

Edit `/etc/postfix/main.cf` and add to the end of virtual_alias_maps:
```
hash:/etc/postfix/virtual
```

Add to /etc/postfix/virtual:
```
@subdomain1.mydomain.tld      user1@mydomain.tld
@subdomain2.mydomain.tld      user1@mydomain.tld
@subdomain3.mydomain.tld      user1@mydomain.tld
@subdomain4.mydomain.tld      user2@mydomain.tld
@subdomain5.mydomain.tld      user3@mydomain.tld
```

Then run:
```
postmap /etc/postfix/virtual
service postfix restart
```

## Allow secondary addresses as sender addresses
Edit `/etc/kolab/kolab.conf` and change address_search_attrs in section [kolab_smtp_access_policy] to:
```
address_search_attrs = mail, alias, mailalternateaddress
```


## Settings for CalDAV client
Use URL:
https://host.mydomain.tld/iRony/calendars/user1@mydomain.tld/Calendar

## Settings for CardDAV client
Use URL:
https://host.mydomain.tld/iRony/addressbooks/user1@mydomain.tld/Contacts

## Settings for Android

Create a *Corporate* account with type *Exchange* and use the following settings:

User name: *your user id*

Server: `host.mydomain.tld`

Port: `443`

Security type: `SSL/TLS`

