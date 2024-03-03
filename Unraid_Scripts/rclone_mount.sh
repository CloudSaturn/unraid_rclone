#!/bin/bash

# Define paths and parameters for all services

# Binary locations
RCLONE_BIN="/usr/sbin/rclone"
MERGERFS_BIN="/usr/bin/mergerfs"
MERGERFS_FUSERMOUNT_BIN="/usr/bin/mergerfs-fusermount"
DOCKER_BIN="/usr/bin/docker"

# Rclone remote name to mount
# rclone subfolder mounting is support via RCLONE_REMOTE="remote:/subfolder/"
RCLONE_REMOTE="remote:/subfolder/"

# Rclone & mergerfs mount points
MOUNT_POINT_REMOTE="/mnt/user/cloud/rclonevfs"
MOUNT_POINT_LOCAL="/mnt/user/cloud/local"
MOUNT_POINT_MERGERFS="/mnt/user/cloud/merged"

# Rclone shared variables
RCLONE_CONFIG="/boot/config/plugins/rclone/.rclone.conf"
LOG_LEVEL="INFO"
LOG_FILE="/mnt/user/cloud/.logs/remote.log"
CACHE_DIR="/mnt/user/cloud/.vfscaching/drive/"
COMMON_RCLONE_OPTIONS="--use-mmap --dir-cache-time 72h --timeout 60s --umask 002 --allow-other --vfs-cache-mode writes --buffer-size 32M --vfs-read-ahead 64M --vfs-read-chunk-size 128M --vfs-read-chunk-size-limit 500M --vfs-cache-max-age 30m --log-level $LOG_LEVEL --tpslimit 12 --fast-list"

# Docker container name
# Add as many as you need in the desired start order
# Example: DOCKER_CONTAINERS=("plex" "container2" "container3")
DOCKER_CONTAINERS=("plex")

# Test mode flag
TEST_MODE=false

# Functions
is_mounted() {
    mountpoint -q "$1"
    return $?
}

network_check() {
    ping -c 1 google.com &> /dev/null
    return $?
}

show_logs() {
    echo -e "\033[34m=== rclone VFS mount logs ===\033[0m"
    cat $LOG_FILE
    echo -e "\033[34m==============================\033[0m"
}

live_status_check() {
    while true; do
        clear
        status
        sleep 2
    done
}

create_required_dirs_and_files() {
    for dir in $MOUNT_POINT_REMOTE $MOUNT_POINT_LOCAL $MOUNT_POINT_MERGERFS; do
        if [ ! -d "$dir" ]; then
            echo -e "\033[33mDirectory $dir does not exist. Creating...\033[0m"
            mkdir -p "$dir"
        fi
    done

    LOG_DIR=$(dirname $LOG_FILE)
    if [ ! -d "$LOG_DIR" ]; then
        echo -e "\033[33mLog directory $LOG_DIR does not exist. Creating...\033[0m"
        mkdir -p "$LOG_DIR"
    fi

    if [ ! -f "$LOG_FILE" ]; then
        echo -e "\033[33mLog file $LOG_FILE does not exist. Creating...\033[0m"
        touch "$LOG_FILE"
    fi
}

start_docker_containers() {
    for container in "${DOCKER_CONTAINERS[@]}"; do
        if ! $DOCKER_BIN ps | grep -q $container; then
            echo -e "\033[32mStarting $container container...\033[0m"
            $DOCKER_BIN start $container
            sleep 5
        else
            echo -e "\033[32m$container container is already running.\033[0m"
        fi
    done
}

stop_docker_containers() {
    for container in "${DOCKER_CONTAINERS[@]}"; do
        if $DOCKER_BIN ps | grep -q $container; then
            echo -e "\033[32mStopping $container container...\033[0m"
            $DOCKER_BIN stop $container
            sleep 5
        fi
    done
}

start() {
    create_required_dirs_and_files
    network_check
    if [ $? -ne 0 ]; then
        echo -e "\033[31mNo network connectivity. Exiting.\033[0m"
        exit 1
    fi

    if ! is_mounted $MOUNT_POINT_REMOTE; then
        echo -e "\033[32mRunning rclone VFS mount...\033[0m"
        $RCLONE_BIN mount $RCLONE_REMOTE $MOUNT_POINT_REMOTE --config $RCLONE_CONFIG --user-agent='Mozilla/5.0' $COMMON_RCLONE_OPTIONS --log-file $LOG_FILE --cache-dir $CACHE_DIR --daemon
    fi

    if ! is_mounted $MOUNT_POINT_MERGERFS; then
        echo -e "\033[32mRunning mergerfs...\033[0m"
        $MERGERFS_BIN $MOUNT_POINT_REMOTE:$MOUNT_POINT_LOCAL $MOUNT_POINT_MERGERFS -o defaults,async_read=false,allow_other,category.action=all,category.create=ff
    fi

    start_docker_containers
}

stop() {
    stop_docker_containers

    if is_mounted $MOUNT_POINT_MERGERFS; then
        $MERGERFS_FUSERMOUNT_BIN -uz $MOUNT_POINT_MERGERFS
    fi

    if is_mounted $MOUNT_POINT_REMOTE; then
        $MERGERFS_FUSERMOUNT_BIN -uz $MOUNT_POINT_REMOTE
    fi
}

status() {
    if is_mounted $MOUNT_POINT_REMOTE; then
        echo -e "\033[32mrclone VFS mount is running.\033[0m"
    else 
        echo -e "\033[31mrclone VFS mount is not running.\033[0m"
    fi

    if is_mounted $MOUNT_POINT_MERGERFS; then
        echo -e "\033[32mmergerfs is running.\033[0m"
    else 
        echo -e "\033[31mmergerfs is not running.\033[0m"
    fi

    for container in "${DOCKER_CONTAINERS[@]}"; do
        if $DOCKER_BIN ps | grep -q $container; then
            echo -e "\033[32m$container container is running.\033[0m"
        else
            echo -e "\033[31m$container container is not running.\033[0m"
        fi
    done
}

ensure() {
    if ! is_mounted $MOUNT_POINT_REMOTE; then
        echo -e "\033[31mrclone VFS mount is not mounted or not functioning correctly. Remounting...\033[0m"
        stop
        start
    fi

    if ! is_mounted $MOUNT_POINT_MERGERFS; then
        echo -e "\033[31mmergerfs not mounted or not functioning correctly. Remounting...\033[0m"
        stop
        start
    fi
}

exit_test_mode() {
    echo -e "\033[31mExiting test mode...\033[0m"
    if is_mounted $MOUNT_POINT_REMOTE; then
        $MERGERFS_FUSERMOUNT_BIN -uz $MOUNT_POINT_REMOTE
    fi
    stop
    exit 0
}

# Check for flags
for arg in "$@"; do
    case $arg in
        --log-level=*)
            LOG_LEVEL="${arg#*=}"
            shift
        ;;
        --test)
            TEST_MODE=true
            trap exit_test_mode SIGINT
            shift
        ;;
    esac
done

# Main script logic
case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        start
        ;;
    status)
        status
        ;;
    log)
        show_logs
        ;;
    ensure)
        ensure
        ;;
    *)
        ensure
esac

# If in test mode, keep the script running in the foreground until Ctrl+C
if $TEST_MODE; then
    echo -e "\033[31mRunning in test mode. Press Ctrl+C to exit.\033[0m"
    live_status_check
fi
