#!/bin/bash

source "/etc/qbittorrent/qbt_utils.bash"

health_check_vpn_down_script() {
  # $1 = VPN_DOWN_SCRIPT
  # returns 0 if the script was executed, 1 if not
  if [[ $1 == 1 && -e "/config/vpn_down.sh" ]]; then
    iprint "VPN_DOWN_SCRIPT is set to $1, executing /config/vpn_down.sh"
    "/config/vpn_down.sh"
    return 0
  fi
  return 1
}

health_check_vpn_down_log() {
  # $1 = VPN_DOWN_LOG
  # returns 0 if the file was written, 1 if not
  if [[ $1 == 2 || $1 == 1 ]]; then
    iprint "VPN_DOWN_LOG is set to $1, writing to: /config/vpn_down.log"
    echo "$(date +%s) $(date +"%Y-%m-%d_%H:%M:%S.%4N")" >> "/config/vpn_down.log"
    return 0
  fi
  return 1
}

health_check_vpn_conf_switch() {
  # $1 = VPN_TYPE
  # $2 = VPN_CONFIG
  # $3 = VPN_CONF_SWITCH
  # $4 = RESTART_CONTAINER
  # returns 0 if the script was executed, 1 if not
  if is_true "$4" && is_true "$3" && [ -e "/etc/qbittorrent/vpn_conf_switch.bash" ]; then
    "/etc/qbittorrent/vpn_conf_switch.bash" "${1}" "/$(printf "%s" "$2" | cut -d '/' -f 2)"
    return 0
  fi
  return 1
}
