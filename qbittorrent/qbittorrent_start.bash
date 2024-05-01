#!/bin/bash

source "/etc/qbittorrent/qbt_utils.bash"

ME="$(basename "$0")"

qbittorrent_start() {
  # $1 = username, eg. "qbittorrent"
  # $2 = groupname, eg. "qbittorrent"
  # $3 = QBT_WEBUI_PORT
  # returns 0 on success, 1 on failure
  aprint "Starting qbittorrent-nox..."
  su -g "$2" -c "/usr/local/bin/qbittorrent-nox --profile=/config >> /config/qBittorrent/data/logs/qbittorrent.log 2>&1 &" "$1"
  local now=$(date +%s)
  while ! pidof qbittorrent-nox > /dev/null 2>&1; do
    # If there isn't a PID in 10 seconds, then something is really wrong.
    if [ $(($(date +%s)-$now)) -gt 10 ]; then
      eprint "$ME: qBittorrent failed to start!"
      return 1
    fi
    sleep 0.1
  done
  local now=$(date +%s)
  # Give qbittorrent-nox some time to get up and ready.
  aprint "Waiting for qbittorrent-nox to be up and ready..."
  while [ $(($(date +%s)-$now)) -lt 15 ]; do 
    # Use cURL to detect when qBittorrent is up and ready.
    if timeout -k 0 0.5 curl -v -d "" localhost:$3 2>&1 | grep -qF "Connected to"; then
      return 0
    fi
    sleep 0.1
  done
  eprint "qbittorrent-nox started but never seemed to be ready."
  return 1
}

if ! (return 0 2>/dev/null); then
  qbittorrent_start "$@";
  exit $?;
fi
