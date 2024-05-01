#!/bin/bash

source "/etc/qbittorrent/qbt_utils.bash"

ME="$(basename "$0")"

start_vpn_start() {
  # $1 = VPN_TYPE
  # $2 = VPN_CONFIG
  # $3 = OVPN_NO_CRED_FILE
  # $4 = VPN_PASSWORD
  # $5 = VPN_USERNAME
  # $6 = VPN_OPTIONS
  # returns 1 on error
  [[ -z "$1" || -z "$2"  || -z "$3" ]] && return 1
  if [ "openvpn" == "$1" ]; then
    if is_true "$3"; then
      exec openvpn --auth-nocache --pull-filter ignore route-ipv6 --pull-filter ignore ifconfig-ipv6 \
        --config "$2" $(echo ${@:6}) --auth-user-pass <(printf "%s\n%s" "$5" "$4") &
    else
      exec openvpn --auth-nocache --pull-filter ignore route-ipv6 --pull-filter ignore ifconfig-ipv6 --config "$2" $(echo ${@:6}) &
    fi
  elif [ "wireguard" == "$1" ]; then
    wg-quick up "$2"
  else
    eprint "$ME: VPN type was not understood, received: $1"
    return 1
  fi
}

if ! (return 0 2>/dev/null); then
  start_vpn_start "$@";
  exit $?;
fi
