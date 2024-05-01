#!/bin/bash

source "/etc/qbittorrent/qbt_utils.bash"

start_wait_for_vpn() {
  # Wait until the tunnel is up, hopefully before $REAP_WAIT.
  # $1 = REAPER_WAIT
  # $2 = REAPER_PID
  # returns 0 on connection found.
  local tunnelstat=""
	while : ; do
		tunnelstat=$(netstat -ie | grep "tun\|tap\|wg")
		if [[ ! -z "${tunnelstat}" ]]; then
      aprint "Connection found."
			# The VPN has connected, now onto configuring iptables
			if [[ "$1" != "0" ]]; then
				iprint "Killing reaper ($2)"
				kill -9 $2
      fi
      return 0
    fi
		sleep 0.5
	done
}

if ! (return 0 2>/dev/null); then
  start_wait_for_vpn "$@";
  exit $?;
fi
