Kolab 3.4 in a Docker container
===============================

This is my version of the Kolab for docker.
Installation is supports automatic configuration **kolab**, **nginx**, **ssl**, **opendkim**, **amavis** and **fail2ban**

Currently under development, but it is already possible to try use.
This file I'll write later, once all completed yet.

Run
---

```bash
docker run \
    --privileged \
    --name kolab \
    -h mail.example.org \
    -v /etc/kolab:/data/etc \
    -v /var/spool/kolab:/data/var/spool \
    -v /var/lib/kolab:/data/var/lib \
    -v /var/log/kolab:/data/var/log \
    -p 80:80 \
    -p 443:443 \
    -p 25:25 \
    -p 587:587 \
    -p 110:110 \
    -p 995:995 \
    -p 143:143 \
    -p 993:993 \
    -p 4190:4190 \
    --privileged \
    -ti \
    kvaps/kolab
```
It should be noted that the `--privileged` option is necessary only for **Fail2ban**, if you do not plan to use **Fail2ban**, you can exclude it.

You can also isolate Kolab from your host, simply replace `-v` options like this:
```bash
    -v /opt/kolab:/data \
```

If it is the first run, you will see the settings page, make your changes and save it, installation will continue...
*(You need to have the base knowledge of the [vi editor](http://google.com/#q=vi+editor))*

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

