#!/bin/bash
if [ "openvpn" == "${VPN_TYPE}" ]; then
  cd /config/openvpn
  exec openvpn --pull-filter ignore route-ipv6 --pull-filter ignore ifconfig-ipv6 --config "${VPN_CONFIG}" &
elif [ "wireguard" == "${VPN_TYPE}" ]; then
  cd /config/wireguard
  if ip link | grep -q `basename -s .conf $VPN_CONFIG`; then
    wg-quick down $VPN_CONFIG || echo "[INFO] $(basename "$0"): WireGuard is down already" | ts '%Y-%m-%d %H:%M:%.S' # Run wg-quick down as an extra safeguard in case WireGuard is still up for some reason
    sleep 0.5 # Just to give WireGuard a bit to go down
  fi
  wg-quick up $VPN_CONFIG
else
  echo "[ERROR] $(basename "$0"): VPN type was not understood, received: ${VPN_TYPE}" | ts '%Y-%m-%d %H:%M:%.S'
fi
