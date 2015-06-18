#!/bin/bash
set_spam_acl ()
{
    kolab sam user/%/Spam@$(hostname -d) anyone p
    sleep 15m 
    set_spam_acl
}
set_spam_acl
