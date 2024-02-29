#!/bin/bash
vpn_pid=""
if [ "openvpn" == "${VPN_TYPE}" ]; then
  vpn_pid=$(echo $(ps -aux | grep "openvpn" | grep -v "grep") | cut -d ' ' -f 2 | grep "^[0-9]\+$");
# elif [ "wireguard" == "${VPN_TYPE}" ]; then
# 1248 ?        00:00:00 wg-crypt-wgnet1
# vpn_pid=$(echo $(ps -e | grep "wg-" | grep -v "grep") | cut -d ' ' -f 1 | grep "^[0-9]\+$");
else
  echo "[ERROR] $(basename "$0"): VPN type is not \"openvpn\", type is: ${VPN_TYPE}" | ts '%Y-%m-%d %H:%M:%.S'
fi
if [ "$vpn_pid" != "" ]; then
  kill -9 $vpn_pid
  sleep 1
  /scripts/vpn_conf_switch.sh "${VPN_TYPE}"
  echo "[INFO] $(basename "$0"): Restarting ${VPN_TYPE}..." | ts '%Y-%m-%d %H:%M:%.S'
  /etc/qbittorrent/vpn_start.bash
fi

