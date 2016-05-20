#!/bin/bash

chk_env() {
    eval env="\$$1"
    val="${env:-$2}"
    if [ -z "$val" ]; then
        echo "err:  Enviroment vaiable \$$1 is not set."
        exit 1
    fi  
    export "$1"="$val"
}

load_defaults() {

    defaults_file="defaults.env"
    prefix="DEFAULT_"

    # Export environment variables from $defaults_file with $prefix
    eval export $(cat $defaults_file | sed -e '/^\#/d' -e '/^$/d' -e 's/^/ /' | tr '\n' ' ' | sed -E 's/ ([a-z2A-Z0-9_]+=\S)/ '$prefix'\1/g')

    # Getting loaded envs
    envs=$(env | grep $prefix | cut -d= -f1 | cut -c $[${#prefix}+1]- | grep -v SERVICE_)

    # Checkinkg envs
    for env in ${envs[@]}; do
        eval 'chk_env "'$env'" "$'${prefix}${env}'"'
    done

}

print_spaces() {
    spaces_count=$( echo $2 - ${#1} | bc)
    eval 'printf "%0.s " {1..'$spaces_count'}'
}

map_dirs() {

    echo "Processing folders:"
    echo "STORAGE   FOLDER                   ACTION"
    echo "------------------------------------------------"
    for storage in "${volumes[@]}"; do

        # Default config dirs
        configdirs=($(eval echo '${'$storage'_dirs[@]}'))
        # User definded dirs
        userdirs=($(env | grep -P '^'${storage^^}'_DIR_[0-9]+=' | cut -d= -f2-))

        for dir in "${configdirs[@]}" "${userdirs[@]}"; do
           dirname=$(basename $dir)
           newdir="/${storage}${dirname}"

           echo -en "$storage"
           print_spaces $storage 10
           echo -en "$dirname"
           print_spaces $dirname 25

           if [ ! -e ${newdir} ]; then
               echo -n '(copy) '
               #cp -Lrp $dir ${newdir} || exit 1
           fi
           if [ ! -e ${newdir} ]; then
               echo -n '(link) '

               # If $dir is symbolyc link
               if [ -L $dir ]; then
                   linkdir="$(readlink $dir)"
                   if [ "$linkdir" = "$newdir" ]; then
                       echo 'error: duplicate dirname!'
                       exit 1
                   #else
                       #rm -rf $linkdir
                       #ln -s $newdir $linkdir || exit 1
                   fi
               fi

               #rm -rf $dir
               #ln -s $newdir $dir || exit 1
           fi
           echo

        done
    done
}
