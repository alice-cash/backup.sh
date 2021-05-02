#!/bin/bash

# Copyright 2018 Alice Cash
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#

SCRIPT_NAME=${0##*/}

function  PRINT_HELP() {
    echo "${SCRIPT_NAME} ( -c config_file | SERVER_NAME BACKUP_ROOT [options] )"
    echo " Options:"
    echo "  -x      : Compress Backups"
    echo "  -m      : Make MySQL Backups"
    echo "  -f      : Make Filesystem Backups"
    echo "  -p path : Specify current backup option. Defaults to /YYY-MM-DD/"
    echo "  -l arr  : Specify a list to retrieve previous backups (as an array)"
    echo "            This is used with -n to remove older backups"
    echo "  -q      : Silent output, other than errors"
    echo "  -n num  : Number of backups to retain. 0 is unlimited."
    echo "  -e args : SSH arguments"
    echo "  -r args : RSYNC arguments"
    echo "  -s path : Specify a Seed path that is first copied to reduce bandwidth"
    echo "            Just a config file can be specified as long as it sets"
    echo "            the required variables."
    echo "  -s path : Specify a Seed path that is first copied to reduce bandwidth"
    echo "  -z      : Don't execute but instead echo all variables."
    echo
    echo " SERVER_NAME can be a FQDN configured in ~/.ssh/config or any required ssh"
    echo " arguments can be supplied via the -e flag."
    echo " In order for MySQL backups to work, the remote server needs ~/.my.cnf to be"
    echo " configured for the mysql and mysqldump commands to have access to the server"
    echo
    echo " The config file is sourced and so can execute any required commands"
    echo " The following variables can be set. only the -c flag is used then"
    echo " Any values with [set] simply need to be set to any value"
    echo " To disable these values set to an empty string or \`unset\` them"
    echo " the file needs to set the [required] variables"
    echo " REMOTE_HOSTNAME    : [required] Remote server to backup FQDN hostname"
    echo " BACKUP_ROOT     : [required] Local working directory for backups"
    echo " COMPRESS        : [set] Enable gzip compression"
    echo " BACKUP_MYSQL    : [set] Do MySQL backups"
    echo " BACKUP_FILES    : [set] Do Filesystem backup"
    echo " QUIET        : [set] Mute output other than errors"
    echo " RETAIN           : Number of backups to retian. 0 is unlimited"
    echo " BACKUP_FOLDER    : Backup directory."
    echo " PAST_BACKUPS     : List of previous backups. This will by default pull a "
    echo "                    list of directories based on YYYY-MM-DD"
    echo " RSYNC_ARGS    : Specify custom arguments for rsync"
    echo " SEED_FOLDER    : Seed Folder is used as a base to reduce bandwidth usage"
    echo "               defaults to \$(date +\"%Y-%m-%d\")"
    echo " SSH_CONNECT_ARGS : SSH arguments."
    echo
    echo " You can use the -z flag to generate a config flag, e.g."
    echo " ${SCRIPT_NAME} -xmf server1 /backup -z > /backup/server1.conf"
    echo " Once saved, you can use just this config in crons, e.g."
    echo " ${SCRIPT_NAME} -c /backup/server1.conf"
    echo
    echo " Backups are stored under the following path:"
    echo " Files: BACKUP_ROOT/path/SERVER_NAME"
    echo " Compressed Files: BACKUP_ROOT/path/SERVER_NAME.tar.gz"
    echo " MySQL: BACKUP_ROOT/path/SERVER_NAME-MYSQL/database_name.sql"
    echo " Compressed MySQL: BACKUP_ROOT/path/SERVER_NAME-MYSQL/database_name.sql.gz"
    echo
    echo " Example cron usage:"
    echo " At midnight: Maintain a daily filesystem backup that overrides previous"
    echo " backups under the folder /backup/daily/server1.myhostname.com/:"
    echo " 0 0 * * * $0 server1.myhostname.com /backup -fp daily"
    echo
    echo " At midnight: Maintain a compressed daily mysql under the folder"
    echo " /backup/YYY-MM-DD/server1.myhostname.com-MYSQL, replacing "
    echo " YYY-MM-DD with todays date:"
    echo " 0 0 * * * $0 server1.myhostname.com /backup -fx"
    echo
    echo " At midnight every sunday morning, generate a daily compressed backup in"
    echo " the file /backup/YYY-MM-DD/server1.myhostname.com.tar.gz, replacing"
    echo " YYY-MM-DD with todays date:"
    echo " 0 0 * * 0 $0 server1.myhostname.com /backup -fx"
}



[[ -z $1 ]] && { echo "No server specified."; PRINT_HELP; exit 1; } || REMOTE_HOSTNAME=$1;
shift
[[ -z $1 ]] && { echo "No Path specified."; PRINT_HELP; exit 1; } || BACKUP_ROOT=$1;
shift

# if REMOTE_HOSTNAME is '-c' then BACKUP_ROOT will actually be the config file

[[ "${REMOTE_HOSTNAME}" == "-c" ]] && CONFIG_FILE=${BACKUP_ROOT} && {
    source ${CONFIG_FILE} || {
        echo "Failed to load ${CONFIG_FILE}" 1>&2;
        PRINT_HELP;
        exit 1;
    }
}

[[ "${REMOTE_HOSTNAME}" == "-c" ]] && [[ "${CONFIG_FILE}" == "${BACKUP_ROOT}" ]] && {
    echo "Error: REMOTE_HOSTNAME or BACKUP_ROOT not configured!";
    echo "Check your config file ${CONFIG_FILE}";
    PRINT_HELP;
    exit 1;
}

while getopts "hxmfqzp:e:c:s:r:l:n:" opt; do
  case ${opt} in
    h )
    PRINT_HELP;
    exit 0;
    ;;
    x )
    COMPRESS=1;
    ;;
    m )
    BACKUP_MYSQL=1;
        ;;
    f )
    BACKUP_FILES=1;
    ;;
    p )
    BACKUP_FOLDER=$OPTARG;
    ;;
    s )
    SEED_FOLDER=$OPTARG;
    ;;
    r )
    RSYNC_ARGS=$OPTARG;
    ;;
    l )
    PAST_BACKUPS=$OPTARG;
    ;;
    n )
    RETAIN=$OPTARG;
    ;;
    q )
    QUIET=1;
    ;;
    e )
    SSH_CONNECT_ARGS=$OPTARG;
    ;;
    c )
    source $OPTARG;
    ;;
    z )
    ECHO_ENV=1;
    ;;
    \? )
        PRINT_HELP
        exit 1;
        ;;
  esac
done

# As this is dynamically generated we need to specify that with the -z flag
[[ -z ${BACKUP_FOLDER} ]] && {
    [[ "${ECHO_ENV}" ]] && BACKUP_FOLDER='$(date +"%Y-%m-%d")' ||
                           BACKUP_FOLDER=$(date +"%Y-%m-%d")
}

[[ -z ${PAST_BACKUPS} ]] && {
    [[ "${ECHO_ENV}" ]] && PAST_BACKUPS='($(find "${BACKUP_ROOT}" -maxdepth 1 -mindepth 1 -type d -regextype posix-extended -regex ".*/[0-9]{4}-[0-9]{2}-[0-9]{2}" | sort))' ||
                           PAST_BACKUPS=($(find "${BACKUP_ROOT}" -maxdepth 1 -mindepth 1 -type d -regextype posix-extended -regex ".*/[0-9]{4}-[0-9]{2}-[0-9]{2}" | sort))
}

[[ -z ${RETAIN} ]] && {
    RETAIN=0
}

[[ "${QUIET}" ]] && V_ARG= || V_ARG='-v'

[[ -z ${RSYNC_ARGS} ]] && RSYNC_ARGS='-aAX --delete-after --inplace --exclude=/dev/* --exclude=/proc/* --exclude=/sys/* --exclude=/tmp/* --exclude=/run/* --exclude=/mnt/* --exclude=/media/* --exclude=/lost+found --exclude=/backup/*'

NUM_TEST='^[0-9]+$'
[[ $RETAIN =~ $NUM_TEST ]] || { echo "error: RETAIN '${RETAIN}' Not a number" >&2; PRINT_HELP; exit 1; }


[[ "${ECHO_ENV}" ]] && {

    echo REMOTE_HOSTNAME="'${REMOTE_HOSTNAME}'"
    echo BACKUP_ROOT="'${BACKUP_ROOT}'"
    echo COMPRESS="'${COMPRESS}'"
    echo BACKUP_MYSQL="'${BACKUP_MYSQL}'"
    echo BACKUP_FILES="'${BACKUP_FILES}'"
    echo PAST_BACKUPS="${PAST_BACKUPS}"
    echo RETAIN="'${RETAIN}'"
    echo QUIET="'${QUIET}'"
    [[ ${BACKUP_FOLDER} == *'$'* ]] && echo BACKUP_FOLDER="${BACKUP_FOLDER}" || echo BACKUP_FOLDER="'${BACKUP_FOLDER}'"
    echo SEED_FOLDER="'${SEED_FOLDER}'"
    echo SSH_CONNECT_ARGS="'${SSH_CONNECT_ARGS}'"
    echo RSYNC_ARGS="'${RSYNC_ARGS}'"
    exit 1;
}

BACKUP_FULL_PATH=${BACKUP_ROOT}/${BACKUP_FOLDER}/${REMOTE_HOSTNAME}
SEED_FULL_PATH=${BACKUP_ROOT}/${SEED_FOLDER}/${REMOTE_HOSTNAME}



[[ -z ${QUIET} ]] && [[ -z ${QUIET} ]] && [[ "${BACKUP_FILES}" ]] && {
    echo -n  "Backing up ${SERVER_NAME} files to ${BACKUP_FULL_PATH}";
    [[ "${COMPRESS}" ]] && echo ".tar.gz" || echo;
}
[[ -z ${QUIET} ]] && [[ "${BACKUP_MYSQL}" ]] && {
    echo -n "Backing up ${SERVER_NAME} MYSQL data to  ${BACKUP_FULL_PATH}-MYSQL";
    [[ "${COMPRESS}" ]] && echo " with gzip compression" || echo;
}

mkdir ${V_ARG} -p ${BACKUP_FULL_PATH}{,-MYSQL}

[[ "${BACKUP_FILES}" ]] && {
    [[ "$SEED_FOLDER" ]] && rsync -aAX ${SEED_FULL_PATH}/ ${BACKUP_FULL_PATH}/
    rsync ${V_ARG} $(echo "${RSYNC_ARGS}") -e "ssh ${SSH_CONNECT_ARGS}" "${REMOTE_HOSTNAME}:/" "${BACKUP_FULL_PATH}/"
    [[ "$COMPRESS" ]] && tar --remove-files ${V_ARG} -czf ${BACKUP_FULL_PATH}{.tar.gz,};
}

[[ "${BACKUP_MYSQL}" ]] && {
    function SSH() {
      ssh ${SSH_CONNECT_ARGS} -- ${REMOTE_HOSTNAME} "$@"
    }

    COMPRESS_COMMAND=;SAVE_EXTENSION=;SAVE_PATH=${BACKUP_FULL_PATH}-MYSQL;

    [[ ${COMPRESS} ]] && { COMPRESS_COMMAND='| gzip -c'; SAVE_EXTENSION='.gz'; };

    for database in $(SSH mysql -sse \"show databases\"); do
        [[ -z ${QUIET} ]] && echo Exporing  ${database} to ${SAVE_PATH}/${database}.sql${SAVE_EXTENSION};
        SSH mysqldump -f ${database} ${COMPRESS_COMMAND} > ${SAVE_PATH}/${database}.sql${SAVE_EXTENSION};
    done

    SSH mysqldump -f mysql user ${COMPRESS_COMMAND} > ${SAVE_PATH}/mysql.user.sql${SAVE_EXTENSION};
}

[[ $RETAIN -gt 0 ]] && {
    PAST_BACKUPS_ARR=(${PAST_BACKUPS[@]});
    while [[  ${#PAST_BACKUPS_ARR[@]} -gt ${RETAIN} ]]; do
        echo Removing ${PAST_BACKUPS_ARR[0]}/${REMOTE_HOSTNAME};
        rm -rf "${PAST_BACKUPS_ARR[0]}/${REMOTE_HOSTNAME}/"
        rm -rf "${PAST_BACKUPS_ARR[0]}/${REMOTE_HOSTNAME}-MYSQL/"
        rmdir ${PAST_BACKUPS_ARR[0]}
        PAST_BACKUPS_ARR=(${PAST_BACKUPS_ARR[@]:1});
    done;

}
