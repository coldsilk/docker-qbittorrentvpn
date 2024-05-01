#!/bin/bash

source "/etc/qbittorrent/qbt_utils.bash"

health_check_run_ping() {
  # $1 = HEALTH_CHECK_PING_TIME
  # $2 = HEALTH_CHECK_AMOUNT
  # $3 = Address to ping
  # returns 0 on success, 1 on failure
  if [[ ! -z "$1" 
  && ! -z "$2" \
  && ! -z "$3" ]];
  then
    timeout -k 0 $1 ping -c ${2} "$3" > /dev/null 2>&1
    # timeout -k 0 $HEALTH_CHECK_PING_TIME ping -c ${HEALTH_CHECK_AMOUNT} "$i" > /dev/null 2>&1
    local rc=$?
    printf "%s" "$rc" | grep "12[4567]\|137" && wprint "Ping timed out on $3"
    [ $rc == 0 ] && return 0
    return 1
  fi
}

if ! (return 0 2>/dev/null); then
  health_check_run_ping "$@";
  exit $?;
fi