#!/bin/bash
set_spam_sieve ()
{
imap_stor=/var/spool/imap
sieve_stor=/var/lib/imap/sieve
 
user_sieve_folders=($(find $imap_stor -name Spam -type d -print | sed 's|'$imap_stor'|'$sieve_stor'|' | sed 's|/user||' | sed 's|/Spam|/|'))
 
for folder in ${user_sieve_folders[@]} ; do
    if [ -f $folder'roundcube.script' ] ; then
        if [ "$(grep -c "include :global \"default\"" $folder'roundcube.script')" -eq 0 ]; then 
            echo Ingect rules $folder'roundcube.script'
            sed -i -e '2 c require "include";\ninclude :global "default";' $folder'roundcube.script'
            /usr/lib/cyrus-imapd/sievec $folder'roundcube.script' $folder'roundcube.bc'
        else
            echo Skipping $folder'roundcube.script'
        fi
    else
        echo Creating new $folder'roundcube.script'
        echo -e 'require "include";\ninclude :global "default";' > $folder'roundcube.script'
        /usr/lib/cyrus-imapd/sievec $folder'roundcube.script' $folder'roundcube.bc'
        ln -s $folder'roundcube.bc' $folder'defaultbc'
    fi  
done

    sleep 15m 
    set_spam_sieve
}
set_spam_sieve
