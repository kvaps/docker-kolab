#!/bin/bash
source '/lib/start/functions.sh'

# Load default environment variables
source image_env

# Check for old image directories
detect_old_image

# Load directories
image_stor || exit 1

if [ -f '/etc/image/version.conf' ]; then
    # Install updates if neded
    image_update || exit 1
elif [ ! -d /etc/dirsrv/slapd-* ]; then
    # First run
    setup_kolab || exit 1
    echo "16-0" > /etc/image/version.conf
else
    >&2 echo "Kolab already installed but version.conf is not exist!"
    exit 1
fi

configure WEBSERVER nginx apache
configure FORCE_HTTPS true false
configure NGINX_CACHE true false
configure SPAM_SIEVE true false
configure SYSLOG true false
configure FAIL2BAN true false
configure DKIM true false
configure CERT_PATH
configure KOLAB_DEFAULT_LOCALE
configure KOLAB_DEFAULT_QUOTA
configure MAX_MEMORY_SIZE
configure MAX_FILE_SIZE
configure MAX_MAIL_SIZE
configure MAX_MAILBOX_SIZE
configure MAX_BODY_SIZE
configure ROUNDCUBE_SKIN larry chameleon
configure ROUNDCUBE_TRASH flag trash
configure_ext_milter_addr
configure_roundcube_plugins

# Start services
start_dirsrv || exit 1
image_services_start || exit 1

echo -------------------------------------------------------------------------------
# Start logs reading
journalctl -b -ef
