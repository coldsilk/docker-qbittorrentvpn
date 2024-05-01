#!/bin/bash

source "/etc/qbittorrent/qbt_utils.bash"

start_find_conf_file() {
  # $1 = VPN_TYPE
  # $2 = MOVE_CONFIGS
  # return 0 if a conf file is found, 1 if not
  # prints conf filename
  local _vpn_config=""
  if [ "$1" == "openvpn" ]; then
		_vpn_config=$(find /config/openvpn -maxdepth 1 -type f -name "default.ovpn" -print -quit)
		if [ -z "$_vpn_config"  ]; then
  		# Wildcard search for *.conf and *.ovpn config files, match on first result
			_vpn_config=$(find /config/openvpn -maxdepth 1 -type f \( -iname "*.conf" -o -iname "*.ovpn" \)  ! -iname "credentials.conf" ! -iname "*userpass*" -print -quit)
		fi
    if is_true "$2" && [ -z "$_vpn_config" ]; then
          _vpn_config=$(find /vpn_files/openvpn -maxdepth 1 -type f -name "default.ovpn" -print -quit)
        if [ -z "$_vpn_config" ]; then
          # Wildcard search for *.conf and *.ovpn config files, match on first result
          _vpn_config=$(find /vpn_files/openvpn -maxdepth 1 -type f \( -iname "*.conf" -o -iname "*.ovpn" \)  ! -iname "credentials.conf" ! -iname "*userpass*" -print -quit)
        fi
    fi
  elif [ "$1" == "wireguard" ]; then
    # For wireguard, first specifically match "wg0.conf"
		_vpn_config=$(find /config/wireguard -maxdepth 1 -type f -name "wg0.conf" -print -quit)
		if [ -z "$_vpn_config" ]; then
			# If wg0.conf was not found, get the first .conf and rename it.
			_vpn_config=$(find /config/wireguard -maxdepth 1 -type f -iname "*.conf" -print -quit)
			if [ ! -z "$_vpn_config" ]; then
				! mv -f "$_vpn_config" "/config/wireguard/wg0.conf"  > /dev/null 2>&1 && return 1
				_vpn_config="/config/wireguard/wg0.conf"
			fi
		fi
    if is_true "$2" && [ -z "$_vpn_config" ]; then
      _vpn_config=$(find /vpn_files/wireguard -maxdepth 1 -type f -name "wg0.conf" -print -quit)
    fi
  fi

  # If MOVE_CONFIGS is enabled, set the _vpn_config root directory to /vpn_files
  if is_true "$2" && [ ! -z "$_vpn_config" ]; then
		_vpn_config="/vpn_files/$1/$(basename "${_vpn_config}")"
  fi
  printf "%s" "$_vpn_config"
  [ ! -z "$_vpn_config" ] && return 0 || return 1;
}
# determine if the script was sourced or not, sourced == true
if ! (return 0 2>/dev/null); then
  start_find_conf_file "$@";
  exit $?;
fi