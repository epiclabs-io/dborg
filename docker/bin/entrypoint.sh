#!/bin/bash

. loadconfig.sh
. logging.sh

export SINGLE_LOGFILE="/logs/log-$(date +"%Y-%m-%d_%H-%M-%S").txt"
export BORG_HOST_ID="synobackup" #makes sure we always identify the same way in case some lock gets stuck

# Backups to keep, see: https://borgbackup.readthedocs.io/en/stable/usage/prune.html
PRUNE_KEEP="--keep-daily 7 --keep-weekly 4 --keep-monthly 6"
# Compression: Algorithm,level
COMP='zstd,6'

# Log verbosity. 4 is normal output (just borg program output, etc
# + warnings, errors and notify), 6 is debug
export LOG_VERBOSITY=6
# Print output to screen or not
export STDOUT_LOG=true

function run_with_timeout() {
    # First parameter is the timeout
    local timeout=$1

    # Remove the first parameter (timeout) from the list
    shift

    # Run the command in the background
    "$@" &
    local command_pid=$!

    # Wait for the command to finish or timeout
    local elapsed=0
    while kill -0 $command_pid 2>/dev/null; do
        if [ "$elapsed" -ge "$timeout" ]; then
            ewarn "Command timed out. Killing the process."
            kill -9 $command_pid
            return 1
        fi
        sleep 1
        ((elapsed++))
    done

    # Wait for the process to completely finish and get the exit status
    wait $command_pid
    local exit_status=$?

    return $exit_status
}

retry_command() {
    local max_attempts=$1
    local name=$2
    shift
    shift

    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        einfo "Attempting $name:"
        "$@"
        local status=$?

        if [ $status -eq 0 ]; then
            return 0
        fi

        ((attempt++))
        sleep 1
    done

    eerror "Command $name failed after $max_attempts attempts"
    return 1
}

function startvpn() {

    echo -e "\n ---------------- CONNECTING ---------------\n" 2>&1

    # Start OpenVPN
    openvpn --config "/config/${BACKUP_OVPN_CONFIG}" --daemon
    sleep 2
    if ! retry_command 10 "SSH HOST PING" ping -c 1 "${BACKUP_SSH_HOST}"; then
        eerror "Could not ping SSH Host"
        exit 1
    fi

    if ! retry_command 10 "BORG INFO TEST" run_with_timeout 10 borg info; then
        eerror "Could not connect to borg server"
        sleep 1
    fi

    echo -e "\n ---------------- CONNECTED ----------------\n" 2>&1
}

function stopvpn() {
    # Close the OpenVPN connection
    # Depending on your OpenVPN setup, this might differ
    killall -SIGINT openvpn
}

function command_info() {
    borg info 2>&1
}

function command_list() {
    borg list "$@" 2>&1
}

function command_delete() {
    borg delete "$@" 2>&1
}

function command_compact() {
    borg compact "$@" 2>&1
}

function command_create() {

    local prefix="$1"
    einfo "Creating backup with prefix $prefix ..."

    local patterns=""

    if [ -n "$BACKUP_BORG_PATTERNS" ]; then
        patterns="--patterns-from /config/$BACKUP_BORG_PATTERNS"
    fi

    if borg create --verbose --stats --show-rc $PROGRESS --compression ${COMP} $patterns "${BORG_REPO}::$prefix"'-{now}' . 2>&1; then
        einfo "Created backup with prefix ${prefix} successfully"
    else
        eerror "Error creating backup with prefix ${prefix}."
        return 1
    fi

    einfo "Pruning repository for prefix ${prefix} with keep config ${PRUNE_KEEP} ..."
    if ! borg prune --list --prefix "${prefix}"'-' --show-rc ${PRUNE_KEEP} $BORG_REPO 2>&1; then
        eerror "Error pruning repository for prefix ${prefix}"
    fi

    einfo "Compacting repository after successfully creating a backup and pruning"

    if ! borg compact; then
        eerror "Error compacting repository"
    fi
}

function command_shell() {

    bash

}

function command_mount() {
    useradd -u "${USER_UID}" mountuser
    # workaround bug in "/usr/lib/python3/dist-packages/borg/fuse.py" where the user must exist with the given id for mount to work:
    if ! getent passwd "${USER_UID}" &>/dev/null; then
        sudo useradd -u "${USER_UID}"
    fi
    if ! getent group "${USER_GID}" &>/dev/null; then
        sudo groupadd -g "${USER_GID}" "mountgroup"
    fi
    cd /
    borg mount --numeric-ids -o uid=${USER_UID},gid=${USER_GID},allow_other $BORG_REPO /backup
    cd "/backup"
    command_shell
    cd /
    borg umount /backup
}

if [ "$1" == "--silent" ]; then
    PROGRESS=""
    shift
else
    PROGRESS="--progress"
fi

command=$1
shift

Log_Open

startvpn

if [ "$#" -eq 0 ]; then
    einfo "Running command '${command}':\n"
else
    einfo "Running command '${command}' with parameters '" "$@" "':\n"
fi

case "$command" in
info)
    command_info "$@"
    ;;
list)
    command_list "$@"
    ;;
create)
    command_create "$@"
    ;;
delete)
    command_delete "$@"
    ;;
compact)
    command_compact "$@"
    ;;
shell)
    command_shell "$@"
    ;;
mount)
    command_mount "$@"
    ;;
*)
    ewarn "running advanced command $command"
    borg "$command" "$@" 2>&1
    ;;
esac

Log_Close

chown "${USER_GID}:${USER_UID}" /logs/*.txt

stopvpn
