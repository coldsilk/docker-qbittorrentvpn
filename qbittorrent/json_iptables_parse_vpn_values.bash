#!/bin/bash

source "/etc/qbittorrent/qbt_utils.bash"

ME="$(basename "$0")"


# json_set_key() {
#   # sets key/value on root of JSON
#   # $1 = input json object
#   # $2 = key
#   # $3 = value
#   # returns jq's return code
#   if [[ ! $3 =~ ^[0-9]+$ ]]; then
#     printf "%s" "$1" | jq ". += {\"$2\": \"$3\"}"
#     return $?
#   else
#     printf "%s" "$1" | jq ". += {\"$2\": $3}"
#     return $?
#   fi
#   return $?
# }

iptables_parse_vpn_values() {
  # $1 = VPN_TYPE
  # $2 = VPN_CONFIG
  # $3 = JSON string, ie. "{}"
  # returns 0 on success, 1 on failure
  if [ "$1" == "openvpn" ]; then
    local vpn_remote_line="$(trim "$(cat "$2" | grep -P -o -m 1 '(?<=^remote\s)[^\n\r]+')")"
    [ -z "$vpn_remote_line" ] && eprint "$ME: Could not find 'remote' line in: $2" && return 1
 		local VPN_REMOTE=$(trim "$(echo "$vpn_remote_line" | grep -P -o -m 1 '^[^\s\r\n]+')")
    local VPN_PORT=$(trim "$(echo "$vpn_remote_line" | grep -P -o -m 1 '(?<=\s)\d{2,5}(?=\s)?+')")
    local VPN_PROTOCOL=$(trim "$(cat "$2" | grep -P -o -m 1 '(?<=^proto\s)[^\r\n]+')")
    [ -z "$VPN_PROTOCOL" ] && local VPN_PROTOCOL=$(trim "$(echo "$vpn_remote_line" | grep -P -o -m 1 'udp|tcp-client|tcp$')")
    if [ -z "$VPN_PROTOCOL" ]; then
      # wprint "VPN_PROTOCOL not found in $2, assuming udp."
      local VPN_PROTOCOL="udp"
    fi
		# required for use in iptables
		[ "$VPN_PROTOCOL" == "tcp-client" ] && local VPN_PROTOCOL="tcp"
                                                           # NOTE: hardcoded '0' at the end for OpenVPN
    local VPN_DEVICE_TYPE="$(trim "$(cat "$2" | grep -P -o -m 1 '(?<=^dev\s)[^\r\n\d]+')")0"
	elif [ "$1" == "wireguard" ]; then
		local vpn_remote_line=$(cat "$2" | grep -P -o -m 1 '(?<=^Endpoint)(\s{0,})[^\n\r]+' | sed -e 's~^[=\ ]*~~')
		[ -z "$vpn_remote_line" ] && eprint "$ME: Could not find 'Endpoint' line in: $2" && return 1
    local VPN_REMOTE=$(echo "$vpn_remote_line" | grep -P -o -m 1 '^[^:\r\n]+')
    local VPN_PORT=$(echo "$vpn_remote_line" | grep -P -o -m 1 '(?<=:)\d{2,5}(?=:)?+')
    local VPN_PROTOCOL="udp"
    local VPN_DEVICE_TYPE="wg0"
	else
    eprint "Invalid VPN_TYPE, received: '$VPN_TYPE'"
    return 2
  fi
  if [[ -z "$VPN_REMOTE" \
  || -z "$VPN_PORT" \
  || -z "$VPN_PROTOCOL" \
  || "$VPN_DEVICE_TYPE" == "0" ]]; then
    eprint "$ME: Missing or invalid required value."
    eprint "$ME:      VPN_CONFIG: $2"
    eprint "$ME:        VPN_TYPE: $1"
    eprint "$ME: vpn_remote_line: $vpn_remote_line"
    eprint "$ME:      VPN_REMOTE: $VPN_REMOTE"
    eprint "$ME:        VPN_PORT: $VPN_PORT"
    eprint "$ME:    VPN_PROTOCOL: $VPN_PROTOCOL"
    eprint "$ME: VPN_DEVICE_TYPE: $VPN_DEVICE_TYPE"
    return 1
  fi
  local _json="$(json_set_key "$3" vpn_remote_line "$vpn_remote_line")"
  _json="$(json_set_key "$_json" VPN_REMOTE "$VPN_REMOTE")"
  _json="$(json_set_key "$_json" VPN_PORT "$VPN_PORT")"
  _json="$(json_set_key "$_json" VPN_PROTOCOL "$VPN_PROTOCOL")"
  _json="$(json_set_key "$_json" VPN_DEVICE_TYPE "$VPN_DEVICE_TYPE")"
  printf "%s" "$_json"
  # iprint "$(print_column vpn_remote_line "\'$vpn_remote_line\'")"
  # iprint "$(print_column VPN_REMOTE "\'$VPN_REMOTE\'")"
  # iprint "$(print_column VPN_PORT "\'$VPN_PORT\'")"
  # iprint "$(print_column VPN_PROTOCOL "\'$VPN_PROTOCOL\'")"
  # iprint "$(print_column VPN_DEVICE_TYPE "\'$VPN_DEVICE_TYPE\'")"
  return 0
}

if ! (return 0 2>/dev/null); then
  iptables_parse_vpn_values "$@";
  exit $?;
fi
