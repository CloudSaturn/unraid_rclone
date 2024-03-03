#!/bin/bash

# Define paths and parameters for all services

# Binary locations
RCLONE_BIN="/usr/sbin/rclone"
MERGERFS_BIN="/usr/bin/mergerfs"
MERGERFS_FUSERMOUNT_BIN="/usr/bin/mergerfs-fusermount"
DOCKER_BIN="/usr/bin/docker"

# Rclone remote name to mount
# rclone subfolder mounting is support via RCLONE_REMOTE="remote:/subfolder/"
RCLONE_REMOTE="remote1:/subfolder/"
RCLONE_REMOTE2="remote2:/subfolder/"

# Rclone & mergerfs mount points
MOUNT_POINT_REMOTE1="/mnt/user/cloud/remote1"
MOUNT_POINT_REMOTE2="/mnt/user/cloud/remote2"
MOUNT_POINT_LOCAL="/mnt/user/cloud/local"
MOUNT_POINT_MERGERFS="/mnt/user/cloud/merged"

# Rclone shared variables
RCLONE_CONFIG="/boot/config/plugins/rclone/.rclone.conf"
LOG_LEVEL="INFO"
LOG_FILE_REMOTE1="/mnt/user/cloud/.logs/remote1.log"
LOG_FILE_REMOTE2="/mnt/user/cloud/.logs/remote2.log"
CACHE_DIR_REMOTE1="/mnt/user/cloud/.vfscaching/remote1/"
CACHE_DIR_REMOTE2="/mnt/user/cloud/.vfscaching/remote2/"
COMMON_RCLONE_OPTIONS="--use-mmap --dir-cache-time 72h --timeout 60s --umask 002 --allow-other --vfs-cache-mode writes --buffer-size 32M --vfs-read-ahead 64M --vfs-read-chunk-size 128M --vfs-read-chunk-size-limit 500M --vfs-cache-max-age 30m --log-level $LOG_LEVEL --tpslimit 12 --fast-list"

# Docker container name
# Add as many as you need in the desired start order
# Example: DOCKER_CONTAINERS=("plex" "container2" "container3")
DOCKER_CONTAINERS=("plex")

# Test mode flag
TEST_MODE=false

# Keep track of the background process IDs for cleanup
declare -A PROCESS_IDS

is_mounted() {
    mountpoint -q "$1"
    return $?
}

network_check() {
    ping -c 1 google.com &> /dev/null
    return $?
}

show_logs() {
    echo -e "\033[34m=== rclone VFS mount logs for remote1 ===\033[0m"
    cat $LOG_FILE_REMOTE1
    echo -e "\033[34m==============================\033[0m"
    echo -e "\033[34m=== rclone VFS mount logs for remote2 ===\033[0m"
    cat $LOG_FILE_REMOTE2
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
    # Check and create mount directories if they don't exist
    for dir in $MOUNT_POINT_REMOTE1 $MOUNT_POINT_REMOTE2 $MOUNT_POINT_LOCAL $MOUNT_POINT_MERGERFS; do
        if [ ! -d "$dir" ]; then
            echo -e "\033[33mDirectory $dir does not exist. Creating...\033[0m"
            mkdir -p "$dir"
        fi
    done

    # Check and create log directory if it doesn't exist
    LOG_DIR=$(dirname $LOG_FILE_REMOTE1)
    if [ ! -d "$LOG_DIR" ]; then
        echo -e "\033[33mLog directory $LOG_DIR does not exist. Creating...\033[0m"
        mkdir -p "$LOG_DIR"
    fi

    # Check and create log files if they don't exist
    for logfile in $LOG_FILE_REMOTE1 $LOG_FILE_REMOTE2; do
        if [ ! -f "$logfile" ]; then
            echo -e "\033[33mLog file $logfile does not exist. Creating...\033[0m"
            touch "$logfile"
        fi
    done
}

kill_existing_containers() {
    for container in "${DOCKER_CONTAINERS[@]}"; do
        if $DOCKER_BIN ps | grep -q $container; then
            echo -e "\033[33m$container container is already running. Killing it...\033[0m"
            $DOCKER_BIN kill $container
            sleep 2 # Give some time for the container to be killed
        fi
    done
}

start_docker_containers() {
    for container in "${DOCKER_CONTAINERS[@]}"; do
        if ! $DOCKER_BIN ps | grep -q $container; then
            echo -e "\033[32mStarting $container container...\033[0m"
            $DOCKER_BIN start $container
            sleep 5 # Give some time for the container to start up
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
            sleep 5 # Allow the container to stop gracefully
        fi
    done
}

start() {
    # Create required directories and files
    create_required_dirs_and_files

    # SanityCheck.sh
    kill_existing_containers

    # Check network connectivity
    network_check
    if [ $? -ne 0 ]; then
        echo -e "\033[31mNo network connectivity. Exiting.\033[0m"
        exit 1
    fi

    # Start rclone VFS mounts
    if ! is_mounted $MOUNT_POINT_REMOTE1; then
        echo -e "\033[32mRunning rclone VFS mount for REMOTE1...\033[0m"
        $RCLONE_BIN mount $RCLONE_REMOTE1_REMOTE $MOUNT_POINT_REMOTE1 --config $RCLONE_CONFIG --user-agent='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.0.0 Safari/537.36' $COMMON_RCLONE_OPTIONS --log-file $LOG_FILE_REMOTE1 --cache-dir $CACHE_DIR_REMOTE1 --daemon
    fi

    if ! is_mounted $MOUNT_POINT_REMOTE2; then
        echo -e "\033[32mRunning rclone VFS mount for REMOTE2...\033[0m"
        $RCLONE_BIN mount $RCLONE_REMOTE2 $MOUNT_POINT_REMOTE2 --config $RCLONE_CONFIG --user-agent='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.0.0 Safari/537.36' $COMMON_RCLONE_OPTIONS --log-file $LOG_FILE_REMOTE2 --cache-dir $CACHE_DIR_REMOTE2 --daemon
    fi

    # Start mergerfs
    if ! is_mounted $MOUNT_POINT_MERGERFS; then
        echo -e "\033[32mRunning mergerfs...\033[0m"
        $MERGERFS_BIN $MOUNT_POINT_REMOTE1:$MOUNT_POINT_REMOTE2:$MOUNT_POINT_LOCAL $MOUNT_POINT_MERGERFS -o defaults,sync_read=false,allow_other,category.action=all,category.create=ff
    fi

    # Start Docker containers
    start_docker_containers
}

stop() {
    # Stop Docker containers
    stop_docker_containers

    # Stop mergerfs
    if is_mounted $MOUNT_POINT_MERGERFS; then
        $MERGERFS_FUSERMOUNT_BIN -uz $MOUNT_POINT_MERGERFS
    fi

    # Stop rclone VFS mounts
    if is_mounted $MOUNT_POINT_REMOTE1; then
        $MERGERFS_FUSERMOUNT_BIN -uz $MOUNT_POINT_REMOTE1
    fi

    if is_mounted $MOUNT_POINT_REMOTE2; then
        $MERGERFS_FUSERMOUNT_BIN -uz $MOUNT_POINT_REMOTE2
    fi
}

status() {
    # Check status of each service
    if is_mounted $MOUNT_POINT_REMOTE1; then
        echo -e "\033[32mrclone VFS mount for REMOTE1 is running.\033[0m"
    else 
        echo -e "\033[31mrclone VFS mount for REMOTE1 is not running.\033[0m"
    fi

    if is_mounted $MOUNT_POINT_REMOTE2; then
        echo -e "\033[32mrclone VFS mount for REMOTE2 is running.\033[0m"
    else 
        echo -e "\033[31mrclone VFS mount for REMOTE2 is not running.\033[0m"
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
    if ! is_mounted $MOUNT_POINT_REMOTE1 || ! is_mounted $MOUNT_POINT_REMOTE2; then
        echo -e "\033[31mOne or more rclone VFS mounts are not mounted or not functioning correctly. Remounting...\033[0m"
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
    if is_mounted $MOUNT_POINT_REMOTE1; then
        $MERGERFS_FUSERMOUNT_BIN -uz $MOUNT_POINT_REMOTE1
    fi
    if is_mounted $MOUNT_POINT_REMOTE2; then
        $MERGERFS_FUSERMOUNT_BIN -uz $MOUNT_POINT_REMOTE2
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