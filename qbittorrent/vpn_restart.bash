#!/bin/bash
vpn_pid=""
if [ "openvpn" == "${VPN_TYPE}" ]; then
  while : ; do
      vpn_pid=$(echo $(ps -aux | grep "${VPN_TYPE}" | grep -v "grep") | cut -d ' ' -f 2 | grep "^[0-9]\+$");
      if [ "$vpn_pid" != "" ]; then
        kill -9 $vpn_pid
      else
        break;
      fi
  done
  sleep 1
  /scripts/vpn_conf_switch.sh "${VPN_TYPE}"
  echo "[INFO] $(basename "$0"): Restarting ${VPN_TYPE}..." | ts '%Y-%m-%d %H:%M:%.S'
  /etc/qbittorrent/vpn_start.bash
else
  echo "[ERROR] $(basename "$0"): VPN type is not \"openvpn\", type is: ${VPN_TYPE}" | ts '%Y-%m-%d %H:%M:%.S'
fi
