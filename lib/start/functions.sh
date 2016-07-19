#!/bin/bash

function chk_env {
    eval env="\$$1"
    val="${env:-$2}"
    if [ -z "$val" ]; then
        >&2 echo "chk_env: Enviroment vaiable \$$1 is not set."
        exit 1
    fi  
    export "$1"="$val"
}

function setup_kolab {
    chk_env LDAP_ADMIN_PASS
    chk_env LDAP_MANAGER_PASS
    chk_env LDAP_CYRUS_PASS
    chk_env LDAP_KOLAB_PASS
    chk_env MYSQL_ROOT_PASS
    chk_env MYSQL_KOLAB_PASS
    chk_env MYSQL_ROUNDCUBE_PASS

    setup_kolab.exp
}

function configure {
    local VARIABLE="$1"
    eval local STATE="\$$VARIABLE"
    local CHECKS="${@:2}"
    if [ -z $STATE ] ; then
        echo "configure: Skiping configure_${VARIABLE,,}, because \$$VARIABLE is not set"
        return 0
    fi
    if ! [ -z "$CHECKS" ] && ! [[ " ${CHECKS[@]} " =~ " ${STATE} " ]] ; then
        >&2 echo "configure: Unknown state $STATE for \$$VARIABLE (need: `echo $CHECKS | sed 's/ /|/g'`)"
        exit 1
    fi

    #configure_${VARIABLE,,} ${STATE}
    echo configure_${VARIABLE,,} ${STATE}
}

function configure_roundcube_plugins {
    local roundcube_plugins=($(env | grep -oP '(?<=^ROUNDCUBE_PLUGIN_)[a-zA-Z0-9_]*'))
    for plugin_var in ${roundcube_plugins[@]} ; do
        local plugin_dir="/usr/share/roundcubemail/plugins"
        local plugin_mask=$(echo $plugin_var | sed 's/_/.?/g')
        local plugin_name=$(ls $plugin_dir -1 | grep -iE "^$plugin_mask$")
        eval local plugin_state=\$ROUNDCUBE_PLUGIN_${plugin_var}

        if $(echo $plugin_name | grep -q ' '); then
            >&2 echo "configure_roundcube_plugins: Duplicate roundcube plugins: $(echo $plugin_name)"
            exit 1
        elif [ -z "$plugin_name" ]; then
            >&2 echo "configure_roundcube_plugins:  Roundcube plugin ${plugin_var,,} not found in $plugin_dir"
            exit 1
        elif ! ( [ "$plugin_state" == true ] || [ "$plugin_state" == false ] ); then
            >&2 echo "configure_roundcube_plugins: Unknown state $plugin_state for roundcube plugin ${plugin_name} (need: true|false)"
            exit 1
        fi

        configure_roundcube_plugin $plugin_name $plugin_state
    done
}

function configure_roundcube_plugin {
    local PLUGIN=$1
    local STATE=$2
    case $STATE in
        true  ) echo enable $PLUGIN ;;
        false ) echo disable $PLUGIN ;;
    esac
}
