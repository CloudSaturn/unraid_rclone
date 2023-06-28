#!/bin/bash

#############################################################################################################################
## Made for Unraid to migrate items from Google Drive to an rclone remote bypassing the 10TB download quota using SAs      ##
## Automated Job will auto lock to prevent multiple runs.                                                                  ##
#############################################################################################################################
## Run command in your 100 'service_account.json' directory ls -v | cat -n | while read n f; do mv -n "$f" "$n.json"; done ##
#############################################################################################################################
##
## Script MUST BE NAMED "TDMigrator" in the User-Scripts Plugin
##
## Script VARS
##########################################################
# Source Remote (Team Drive)                             #
# Destination Remote (ie Dropbox, OneDrive, etc)         #
# Log File Date Stamp Format                             #
# RClone Config file location                            #
# rclone lock file location (scripts working directory)  #
##########################################################
COUNTER=0 ## !!!DO NOT TOUCH COUNTER!!! ##
##########################################################
SOURCE="teamdrive:/"                          # Source Remote (Team Drive)
DESTINATION="nongoogleremote:/"               # Destination Remote (ie Dropbox, OneDrive, etc)
DateStamp=$(date +%Y-%b-%d -d "yesterday")    # Log File Date Stamp Format
RCLONE_LOG="/mypath/migration.log"            # Log File Location
RCLONE_CONFIG="/mypath/rclone.conf"           # RClone Config file
RCLONE_LOCK="/mypath/rclone.lock"             # rclone lock file location (scripts working directory)
RCLONE_SA='/mypath/accounts'                  # Service Account JSON directory 
##########################################################
export TERM='xterm-256color'
export RCLONE_CONFIG

_cyan=$(tput setaf 6)
_green=$(tput setaf 2)
function _info() {
  printf "\n\n${_cyan}➜ %s${_norm}\n" "$@"
}
function _success() {
  printf "${_green}✓ %s${_norm}\n" "$@"
}
function _cleanLock() {
  _info "Clearing lock from Ctrl+C intercept"
  rm -f $RCLONE_LOCK
  _success "rclone.lock successfully removed."
  exit 1
}
trap _cleanLock SIGINT

if pidof -o %PPID -x "/tmp/user.scripts/tmpScripts/TDMigrator/script"; then
	exit 1
fi

if [[ ! -f "$RCLONE_LOCK" ]]; then
  touch "$RCLONE_LOCK"
  while [ $COUNTER -lt 100 ]; do
  echo [$(date +%H:%M:%S)] Using service account $COUNTER
  /usr/sbin/rclone --config="$RCLONE_CONFIG" \
  move \
  "$SOURCE" \
  "$DESTINATION" \
  --log-file "$RCLONE_LOG" \
  --drive-service-account-file "$RCLONE_SA/$COUNTER.json" \
  --drive-stop-on-download-limit=true \
  --drive-chunk-size 128M \
  --dropbox-batch-mode sync \
  --dropbox-batch-size 1000 \
  --dropbox-batch-timeout 10s \
  --dropbox-chunk-size 128M \
  --user-agent "DropboxDesktopClient/177.3.5390 (mac; 13.4.0; aarch64; en_US)" \
  --fast-list \
  --transfers 6 \
  --tpslimit 12 \
  --checkers 12 \
  --drive-acknowledge-abuse -vv \
  -P
  exitcode=$?
  if [ $exitcode -eq 0 ]; then
  echo [$(date +%H:%M:%S)] Everything is up to date and synced!
  exit $exitcode
  fi
  let COUNTER=COUNTER+1
  done
  rm -f "$RCLONE_LOCK"
  echo [$(date +%H:%M:%S)] Ran out of all Service Accounts. Quitting. > "$RCLONE_LOG"
else
  exit 1
fi
