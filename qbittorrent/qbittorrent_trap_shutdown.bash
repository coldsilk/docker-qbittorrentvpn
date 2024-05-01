#!/bin/bash

source "/etc/qbittorrent/qbt_utils.bash"

ME="$(basename "$0")"

# trap for shutdown
qbittorrent_trap_shutdown() {
  iprint "Received SIGTERM. Stopping container..."
  if [[ $VPN_DOWN_LOG == 3 ]]; then
    iprint "VPN_DOWN_LOG is set to $VPN_DOWN_LOG, writing to: /config/vpn_down.log"
    echo "$(date +%s) $(date +"%Y-%m-%d_%H:%M:%S.%4N")" >> "/config/vpn_down.log";
  fi
  if [[ $VPN_DOWN_SCRIPT == 2 && -e "/config/vpn_down.sh" ]]; then
    iprint "VPN_DOWN_SCRIPT is set to $VPN_DOWN_SCRIPT, executing /config/vpn_down.sh"
    "/config/vpn_down.sh";
  fi
  local webui_port="$(cat "/config/qBittorrent/config/qBittorrent.conf" | grep '^[\t ]*WebUI\\Port[\t ]*' | sed 's~^[\t ]*WebUI\\Port=[\t=\ ]*~~')"
  if [ -z "$webui_port" ]; then webui_port=$QBT_WEBUI_PORT; fi
  if [ -z "$webui_port" ]; then webui_port=8080; fi
  # For this curl command to work, you must enable the option
  # "Bypass authentication for clients on localhost"
  # or "Bypass authentication for clients in whitelisted IP subnets"
  # or set _QBT_USERNAME and _QBT_PASSWORD
  # As of qBittorrent v4.6.4, the 2 authentication options are under the "Web UI" tab.
  iprint "Attempting to shutdown qBittorrent with cURL."
  iprint "Sending: curl -v -d \"username=$_QBT_USERNAME&password=$_QBT_PASSWORD\" -X POST localhost:$webui_port/api/v2/auth/login"
  IFS='=;' read -ra sid <<< $(curl -v -d "username=$_QBT_USERNAME&password=$_QBT_PASSWORD" -X POST localhost:$webui_port/api/v2/auth/login 2>&1 | grep "SID");
  iprint "Sending: curl -v -H "Cookie: SID=${sid[1]}" -X POST localhost:$webui_port/api/v2/app/shutdown"
  local curl_print="$(curl -v -H "Cookie: SID=${sid[1]}" -X POST localhost:$webui_port/api/v2/app/shutdown 2>&1)"
  printf "%s\n" "$curl_print"
  if ! printf "%s" "$curl_print" | grep -qF "HTTP/1.1 200 OK"; then
    # Try again but, with a different method. _QBT_USERNAME and _QBT_PASSWORD will not matter here.
    # This method is for when "SID" doesn't parse and 1 of the authentication options are enabled.
    eprint "$ME: cURL failed to receive the correct response the 1st time."
    eprint "$ME: Trying a way that requires 1 of the authentication options."
    curl_print="$(curl -v -d "" localhost:$webui_port/api/v2/app/shutdown 2>&1)"  
    printf "%s\n" "$curl_print"
  fi
  # If "HTTP/1.1 200 OK" was NOT received, send SIGINT
  if ! printf "%s" "$curl_print" | grep -qF "HTTP/1.1 200 OK"; then
    wprint "cURL request to shutdown failed, sending SIGINT to qBittorrent pid: $qbittorrentpid"
    wprint "NOTE: cURL requires: \"Bypass authentication for clients on localhost\""
    wprint "     or \"Bypass authentication for clients in whitelisted IP subnets\""
    wprint "     or setting _QBT_USERNAME and _QBT_PASSWORD."
    wprint "     The 2 authentication options are in qBittorrent under the "Web UI" tab"
    kill -2 $qbittorrentpid &
  else
    iprint "cURL received \"HTTP/1.1 200 OK\" after sending the shutdown command."
    if is_true "$internal_shutdown"; then
      iprint "Shut down will be clean if the time out isn't reached ($SHUTDOWN_WAIT seconds)."
    fi
  fi
  # If the request isn't internal, wait on $qbittorrentpid to exit, then exit.
  if ! is_true "$internal_shutdown" || [[ $SHUTDOWN_WAIT == 0 ]]; then
    iprint "Waiting on qBittorrent ($qbittorrentpid) to exit, will say BYE when it does."
    while ps -o pid= -p $qbittorrentpid > /dev/null 2>&1; do
      sleep 1
    done
    exiting 0
  fi
  local now=$(date +%s)
  while ps -o pid= -p $qbittorrentpid > /dev/null 2>&1; do
    iprint "Waiting on the qBittorrent process to exit. PID: $qbittorrentpid"
    sleep 1
    if [ $(($(date +%s)-$now)) -gt $SHUTDOWN_WAIT ]; then
      kill -9 $qbittorrentpid
      eprint "$ME: The qBittorrent process was still running at exit."
      exiting 99;
    fi
  done
  exiting 0
}

if ! (return 0 2>/dev/null); then
  trap_shutdown "$@";
  exit $?;
fi
