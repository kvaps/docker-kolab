#!/bin/bash
set_spam_sieve ()
{
imap_stor=/var/spool/imap/
sieve_stor=/var/lib/imap/sieve/
 
user_sieve_folders=($(find $imap_stor -name Spam -type d -print | sed 's|'$imap_stor'|'$sieve_stor'|' | sed 's|/user||' | sed 's|/Spam|/|'))
 
for folder in ${user_sieve_folders[@]} ; do

    if [ -f $folder'USER.script' ] ; then

        cd $folder

        if [ "$(grep -c 'require.*include' 'USER.script')" -eq 0 ]; then 
            echo 'Inject  require "include";  '$folder'USER.script'
            sed -i '1i require "include";' 'USER.script'
            /usr/lib/cyrus-imapd/sievec 'USER.script' 'USER.bc'
            chown -R cyrus:mail $folder
        fi

        if [ "$(grep -c "include.*:global.*default" 'USER.script')" -eq 0 ]; then 
            echo 'Inject  include :global "default";  '$folder'USER.script'
            echo 'include :global "default";' >> $folder'USER.script'
            /usr/lib/cyrus-imapd/sievec 'USER.script' 'USER.bc'
            chown -R cyrus:mail $folder
        fi

        echo -e $folder'USER.script'

    else

        echo Creating new  $folder'USER.script'
        mkdir -p $folder
        cd $folder
        echo -e 'require ["include"];\ninclude :global "default";' > 'USER.script'
        /usr/lib/cyrus-imapd/sievec 'USER.script' 'USER.bc'
        ln -s 'USER.bc' 'defaultbc'
        chown -R cyrus:mail $folder

    fi  

done

    sleep $SPAM_SIEVE_TIMEOUT 
    set_spam_sieve
}
set_spam_sieve
