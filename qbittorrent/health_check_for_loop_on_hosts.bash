#!/bin/bash

source "/etc/qbittorrent/qbt_utils.bash"

health_check_for_loop_on_hosts() {
  # $1 = HEALTH_CHECK_PING_TIME
  # $2 = HEALTH_CHECK_AMOUNT
  # $3 = failures
  # $4 = HEALTH_CHECK_FAILURES
  # $5...n = _hosts[@]
  # returns 0 on success, 1 on failure
  local HEALTH_CHECK_PING_TIME="$1"
  local HEALTH_CHECK_AMOUNT="$2"
  local failures="$3"
  local HEALTH_CHECK_FAILURES="$4"
  shift; shift; shift; shift;
  for i in "$@"; do
    if "/etc/qbittorrent/health_check_run_ping.bash" "$HEALTH_CHECK_PING_TIME" "$HEALTH_CHECK_AMOUNT" "$i"; then
      return 0
    fi
    wprint "Failed to ping $i. HC failures: $failures/$HEALTH_CHECK_FAILURES."
  done
  return 1
}

if ! (return 0 2>/dev/null); then
  health_check_for_loop_on_hosts "$@";
  exit $?;
fi