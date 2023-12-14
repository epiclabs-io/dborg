#!/bin/bash
HERE=$(dirname "$(realpath "$0")")
docker_extra=""

function prune_logs() {
    # Assign the folder path to a variable
    logs_path="$HERE/logs"

    # Check if the given folder exists
    if [ ! -d "$logs_path" ]; then
        echo "Error: Log file '$logs_path' does not exist."
        exit 1
    fi

    # Delete log .txt files older than 6 months
    find "$logs_path" -name '*.txt' -mtime +180 -exec rm {} \;

    # force Cloud sync to pick up changes
    touch -a $logs_path/*
}

function is_dir_empty() {
    local directory=$1

    # Check if the directory is empty
    if [ -z "$(ls -A "$directory")" ]; then
        return 0 # Return 0 to indicate the directory is empty
    else
        return 1 # Return 1 to indicate the directory is not empty
    fi
}

function get_media_mount_dir() {
    local base_dir="/media"
    local base_name="backup"
    local counter=0
    local dir_path

    while true; do
        if [ $counter -eq 0 ]; then
            dir_path="$base_dir/$base_name"
        else
            dir_path="$base_dir/${base_name}${counter}"
        fi

        # Check if directory does not exist or is empty
        if [ ! -d "$dir_path" ] || [ -z "$(ls -A "$dir_path")" ]; then
            echo $dir_path
            return 0
        fi

        ((counter++))
    done
}

function check_fuse_installed() {
    if ! dpkg -s fuse &>/dev/null; then
        echo "FUSE is not installed. Install FUSE first"
        exit 1
    fi
}

function check_docker_installed_and_usable() {
    if ! command -v docker &>/dev/null; then
        echo "Docker is not installed. Install Docker first"
        exit 1
    fi

    if ! docker info &>/dev/null; then
        echo "Docker is installed but not usable by the current user. Add user to docker group."
        exit 2
    fi
}

function print_usage() {
    echo -e "\ndBorg -- Borg over OpenVPN tool. (c) Epic Labs 2023"
    echo -e "\n usage:\n"
    echo -e "dborg.sh <command> parameters ...\n"
    echo "commands:"
    echo "create <prefix> <local path> : Creates a backup archive of the given local path with a prefix"
    echo "shell [local_path] : opens a shell to run borg commands. If a local_path is given, it will be mapped from the host"
    echo "mount [mount point path] : mounts the backup repository in the given local path. If ommited, it will mount in /media/backup"
    echo "any other command is passed to borg in the container."
    echo ""
}

function run() {
    check_docker_installed_and_usable

    docker run --rm \
        --cap-add=NET_ADMIN \
        --device /dev/net/tun \
        $docker_extra \
        --name borgbackup \
        -e "USER_UID=$(id -u)" -e "USER_GID=$(id -g)" \
        -v $HERE/config:/config \
        -v $HERE/logs:/logs \
        -v cache:/root/.cache \
        epiclabs/dborg "$@"

}

function add_docker_extra() {
    docker_extra="${docker_extra} $*"
}

function map_backup_vol() {
    local local_dir="$1"
    local shared="$2"

    if [ ! -d "$local_dir" ]; then
        echo "Error: Directory $local_dir does not exist."
        exit 1
    fi

    if [ "$shared" != "" ]; then
        shared=":shared"
    fi

    add_docker_extra "-v${local_dir}:/backup$shared"
}

function command_create() {
    local prefix="$1"
    local local_dir="$2"

    map_backup_vol "$local_dir"

    run create "$prefix"
}

function command_shell() {
    local local_dir="$1"

    if [ "$local_dir" != "" ]; then
        map_backup_vol "$local_dir"
    fi

    add_docker_extra "-it"

    run shell

}

function command_mount() {
    check_fuse_installed

    local local_dir="$1"
    if [ "$local_dir" != "" ]; then
        if ! is_dir_empty "$local_dir"; then
            echo "$local_dir must be empty to use as mount point"
            exit 1
        fi
    else
        local_dir="$(get_media_mount_dir)"
    fi

    map_backup_vol "$local_dir" true
    add_docker_extra "-it"
    add_docker_extra "--cap-add SYS_ADMIN --device /dev/fuse --privileged"

    run mount
}

function command_build() {
    pushd "$HERE/docker" || exit 1 >/dev/null
    if ! ./build.sh; then
        echo "Error building Docker image"
        popd >/dev/null || exit 1
        exit 1
    fi
    popd >/dev/null || exit 1
}

function command_deleteprefix() {
    local prefix="$1"

    if [ "$prefix" == "" ]; then
        echo -e "Error: missing prefix\n"
        print_usage
        exit 1
    fi

    run delete --prefix "$prefix"

}

if [ "$1" == "" ]; then
    print_usage
    exit 1
fi

if [ "$1" == "--help" ]; then
    print_usage
    exit 0
fi

command="$1"
shift

echo "running command $command with parameters $*"

case "$command" in
create)
    command_create "$@"
    ;;
shell)
    command_shell "$@"
    ;;
mount)
    command_mount "$@"
    ;;
build)
    command_build "$@"
    ;;
deleteprefix)
    command_deleteprefix "$@"
    ;;
*)
    run "$command" "$@"
    ;;
esac

prune_logs
