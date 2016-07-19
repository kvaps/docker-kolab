#!/bin/bash

# Load default environment variables
load_envs || exit 1

# Load directories
load_dirs || exit 1

## Install updates if neded
#install_updates

# First run
[ -d /etc/dirsrv/slapd-* ] && setup_kolab

#case $WEBSERVER in 
#    nginx  ) enable_nginx  ; disable_apache ;;
#    apache ) enable_apache ; disable_nginx  ;;
#    *      ) echo "Unknown parameter for \$WEBSERVER: $1 (need: nginx|apache) "; exit 1 ;; 
#esac
#
## Bool options
#for i in NGINX_CACHE FORCE_HTTPS SPAM_SIEVE FAIL2BAN DKIM KOLAB_RCPT_POLICY ROUNDCUBE_ZIPDOWNLOAD; do
#    case eval \$$i in
#        true  ) enable_${i,,} ;;
#        false ) disable_${i,,} ;;
#        *     ) echo "Unknown parameter for \$$i: $1 (need: true|false)"; exit 1 ;; 
#    esac
#done

configure WEBSERVER nginx apache
configure FORCE_HTTPS true false
configure NGINX_CACHE true false
configure SPAM_SIEVE true false
configure FAIL2BAN true false
configure DKIM true false
configure CERT_PATH
configure KOLAB_DEFAULT_LOCALE
configure MAX_MEMORY_SIZE
configure MAX_FILE_SIZE
configure MAX_MAIL_SIZE
configure MAX_MAILBOX_SIZE
configure MAX_BODY_SIZE
configure ROUNDCUBE_SKIN larry chameleon
configure ROUNDCUBE_ZIPDOWNLOAD true false
configure ROUNDCUBE_TRASH flag trash
configure EXT_MILTER_ADDR
