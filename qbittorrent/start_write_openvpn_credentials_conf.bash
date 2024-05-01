#!/bin/bash

source "/etc/qbittorrent/qbt_utils.bash"

ME="$(basename "$0")"

start_write_openvpn_credentials_conf() {
  # NOTE: I've made this option obsolete with other options.
  # $1 = VPN_USERNAME
  # $2 = VPN_PASSWORD
  # $3 = MOVE_CONFIGS
  # $4 = VPN_CONFIG
  # returns 0 on write, 1 no write or no write permission
  [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" ]] && return 1
  if [[ ! -z "${VPN_USERNAME}" ]] && [[ ! -z "${VPN_PASSWORD}" ]]; then
    if is_true "$MOVE_CONFIGS"; then
      ! printf "%s\n" "${VPN_USERNAME}" > /vpn_files/openvpn/credentials.conf && return 1
      ! printf "%s\n" "${VPN_PASSWORD}" >> /vpn_files/openvpn/credentials.conf && return 1
    else
      if [[ -w "/config/openvpn" ]]; then
        ! printf "%s\n" "${VPN_USERNAME}" > /config/openvpn/credentials.conf && return 1
        ! printf "%s\n" "${VPN_PASSWORD}" >> /config/openvpn/credentials.conf && return 1
      else
        eprint "$ME: /config/openvpn is not writeable. Cannot create credentials.conf."
        return 1
      fi
    fi

    # Replace line with one that points to credentials.conf
    if cat "${VPN_CONFIG}" | grep -m 1 'auth-user-pass'; then
      # Get line number of auth-user-pass
      local LINE_NUM=$(grep -Fn -m 1 'auth-user-pass' "${VPN_CONFIG}" | cut -d: -f 1)
      ! sed -i "${LINE_NUM}s/.*/auth-user-pass credentials.conf/" "${VPN_CONFIG}" && return 1
    else
      ! sed -i "1s/^/auth-user-pass credentials.conf\n/" "${VPN_CONFIG}" && return 1
    fi
    return 0
  fi
}
# determine if the script was sourced or not, sourced == true
if ! (return 0 2>/dev/null); then
  start_write_openvpn_credentials_conf "$@";
  exit $?;
fi
