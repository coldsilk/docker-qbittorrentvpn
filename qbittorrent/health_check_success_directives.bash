#!/bin/bash

source "/etc/qbittorrent/qbt_utils.bash"

health_check_vpn_up_script() {
  # $1 = VPN_UP_SCRIPT
  # returns 0 if the script was executed, 1 if not
  if is_true "$1" && [ -e "/config/vpn_up.sh" ]; then
    iprint "VPN_UP_SCRIPT is set to $1, executing /config/vpn_up.sh"
    "/config/vpn_up.sh"
    return 0
  fi
  return 1
}

health_check_vpn_down_log_rm() {
  # $1 = VPN_DOWN_LOG
  # returns 0 if rm was executed, 1 if not
  if [[ $1 == 1 ]]; then
    iprint "VPN_DOWN_LOG is $1, removing: /config/vpn_down.log"
    rm -f "/config/vpn_down.log" > /dev/null 2>&1
    return 0
  fi
  return 1
}
