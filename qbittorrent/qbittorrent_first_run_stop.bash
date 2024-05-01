#!/bin/bash

source "/etc/qbittorrent/qbt_utils.bash"

ME="$(basename "$0")"

qbittorrent_first_run_stop() {
  # $@ None
  # returns 0 on success, 1 on failure
  # When using Wireguard on first run, sometimes qbittorrent-nox simply won't
  # download anything until it has been restarted once. I haven't had this 
  # problem with OpenVPN so hopefully it's just my VPN provider.
  local qbittorrentpid=$(pidof qbittorrent-nox)
  local now=$(date +%s)
  aprint "Getting qbittorrent-nox's PID..."
  while [ -z "$qbittorrentpid" ]; do
    # If there isn't a PID in 10 seconds, then something is really wrong.
    if [ $(($(date +%s)-$now)) -gt 10 ]; then
      eprint "$ME: Failed to get qbittorrent-nox's PID for stopping."
      return 1
    fi
    sleep 0.1
    qbittorrentpid=$(pidof qbittorrent-nox)
  done
  # Now interrupt it to stop it.
  kill -SIGINT $qbittorrentpid &
  now=$(date +%s)
  aprint "Stopping qbittorrent-nox..."
  while ps -o pid= -p $qbittorrentpid > /dev/null 2>&1; do
    if [ $(($(date +%s)-$now)) -gt 30 ]; then
      eprint "$ME: Failed to stop qbittorrent-nox."
      return 1
    fi
    sleep 0.1
  done
  return 0
}

if ! (return 0 2>/dev/null); then
  qbittorrent_first_run_stop "$@";
  exit $?;
fi
