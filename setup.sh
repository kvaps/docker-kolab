#!/bin/bash

get_config()
{
    while IFS="=" read var val
    do
        if [[ $var == \[*] ]]
        then
            section=`echo "$var" | tr -d "[] "`
        elif [[ $val ]]
        then
            if [[ $val == "random" ]]
            then
		random_pwd="$(cat /dev/urandom | env LC_CTYPE=C tr -dc a-zA-Z0-9 | head -c 16; echo)"	# gen pass
                eval $section"_"$var=$random_pwd
		sed -i "/\(^"$var"=\).*/ s//\1"$random_pwd"/ " $1	#save generated pass to settings.ini
            else
                eval $section"_"$var="$val"
            fi
        fi
    done < $1
}
set_hostname()
{
    old_hostname="$(cat /etc/hostname)"
    new_hostname="$(echo $main_hostname | cut -d. -f1)"
    new_domain="$(echo $main_hostname | cut -d. -f2-)"
    echo $main_hostname > /etc/hostname
    sed -e "s/$old_hostname/$main_hostname\ $new_hostname/g" /etc/hosts | tee /etc/hosts
}

configure_kolab()
{
if [[ $main_configure_kolab == "true" ]]
    set_hostname
then
    adduser dirsrv
    expect <<EOF
    spawn   setup-kolab --fqdn=$main_hostname --timezone=$kolab_Timezone_ID'
    set timeout 300
    expect  "Administrator password *:"
    send    "$kolab_Administrator_password\r"
    expect  "Confirm Administrator password:"
    send    "$kolab_Administrator_password\r"
    expect  "Directory Manager password *:"
    send    "$kolab_Directory_Manager_password\r"
    expect  "Confirm Directory Manager password:"
    send    "$kolab_Directory_Manager_password\r"
    expect  "User *:"
    send    "dirsrv\r"
    expect  "Group *:"
    send    "dirsrv\r"
    expect  "Please confirm this is the appropriate domain name space"
    send    "yes\r"
    expect  "The standard root dn we composed for you follows"
    send    "yes\r"
    expect  "Cyrus Administrator password *:"
    send    "$kolab_Cyrus_Administrator_password\r"
    expect  "Confirm Cyrus Administrator password:"
    send    "$kolab_Cyrus_Administrator_password\r"
    expect  "Kolab Service password *:"
    send    "$kolab_Kolab_Service_password\r"
    expect  "Confirm Kolab Service password:"
    send    "$kolab_Kolab_Service_password\r"
    expect  "What MySQL server are we setting up"
    send    "2\r"
    expect  "MySQL root password *:"
    send    "$kolab_MySQL_root_password\r"
    expect  "Confirm MySQL root password:"
    send    "$kolab_MySQL_root_password\r"
    expect  "MySQL roundcube password *:"
    send    "$kolab_MySQL_root_password\r"
    expect  "Confirm MySQL roundcube password:"
    send    "$kolab_MySQL_root_password\r"
    expect  "Cyrus Administrator password *:"
    send    "$kolab_Cyrus_Administrator_password\r"
    expect  "Confirm Cyrus Administrator password:"
    send    "$kolab_Cyrus_Administrator_password\r"
    expect  "Starting kolabd:"
    exit    0
EOF
fi
}

get_config settings.ini
configure_kolab
