Kolab 3.4 in a Docker container
===============================

This is my version of the Kolab for docker.
Installation is supports automatic configuration **kolab**, **nginx**, **ssl**, **opendkim**, **amavis** and **fail2ban**

Run
---

```bash
docker run \
    --privileged \
    --name kolab \
    -h mail.example.org \
    -v /opt/kolab:/data:rw \
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

ExecStart=/bin/bash -c '/usr/bin/docker run --name ${DOCKER_NAME} -h ${DOCKER_HOSTNAME} -v ${DOCKER_VOLUME}:/data:rw ${DOCKER_OPTIONS} kvaps/kolab'
ExecStartPost=/bin/bash -c ' \
        pipework ${EXT_INTERFACE} -i eth1 ${DOCKER_NAME} ${EXT_ADDRESS}@${EXT_GATEWAY}; \
        pipework ${INT_BRIDGE} -i eth2 ${DOCKER_NAME} ${INT_ADDRESS}; \
        docker exec ${DOCKER_NAME} ${INT_ROUTE}; \

ExecStop=/bin/bash -c 'docker stop -t 2 ${DOCKER_NAME} && docker rm -f ${DOCKER_NAME}'

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
DOCKER_OPTIONS='--cap-add=NET_ADMIN --net=none'
 
EXT_INTERFACE=eth2
EXT_ADDRESS='10.10.10.123/24'
EXT_GATEWAY='10.10.10.1'
 
INT_BRIDGE=br0
#INT_ADDRESS='192.168.10.123/24'
INT_ADDRESS='dhclient'
INT_ROUTE='ip route add 192.168.1.0/24 via 192.168.10.1'
```
Just simple use:
```bash
systemctl enable kolab@example.org
systemctl start kolab@example.org
```

For setup and manage container, can use [kolab-worker.sh](https://github.com/kvaps/docker-kolab/blob/master/kolab-worker.sh) script
