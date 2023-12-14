#!/bin/bash

function readConfig() {

    shopt -s extglob
    while IFS='=' read -r lhs rhs; do
        if [[ ! $lhs =~ ^\ *# && -n $lhs ]]; then
            rhs="${rhs%%\#*}"  # Del in line right comments
            rhs="${rhs%%*( )}" # Del trailing spaces
            rhs="${rhs%\"*}"   # Del opening string quotes
            rhs="${rhs#\"*}"   # Del closing string quotes
            export $lhs="$rhs"
        fi
    done <"$1"

}

readConfig "/config/backup.conf"

export BORG_REPO="${BACKUP_SSH_USER}@${BACKUP_SSH_HOST}:${BACKUP_SSH_PATH}"
export BORG_RSH="ssh -i "/config/${BACKUP_SSH_KEYFILE}" -o StrictHostKeyChecking=no -o ServerAliveInterval=1 -o ServerAliveCountMax=5"
export BORG_PASSPHRASE=$(cat "/config/${BACKUP_BORG_REPOKEY}")
