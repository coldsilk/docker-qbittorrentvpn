#!/bin/bash

source "/scripts/printers.bash"

is_true() {
  if [[ ! -z "$1" \
  && "${1}" == "1" \
  || "${1,,}" == "true" \
  || "${1,,}" == "yes" \
  || "${1,,}" == "on" ]];
  then return 0; fi
  return 1;
}

util_is_ipv4() {
  # $* : 3 forms supported.
  #       "172.16.34.55/32"
  #    or "172.16.34.55"
  #    or "172.16.34.55:45634"
  # Uses the below 3 regexes.
  # local _0_255="\(25[0-5]\|2[0-4][0-9]\|[01]\?[0-9][0-9]\?\)" # range: [0, 255]
  # local _mask="\(/[12][0-9]\|/3[210]\|/[0-9]\)" # range: [0, 32]
  # local _port="\(:[0-5]\?[0-9]\{0,4\}$\|:6[0-5][0-5][0-3][0-5]$\)" # range: [0, 65535]
  # Expression: ^(_0_255)(_mask|_port)?$
  if [ "$*" != "" ]; then
    if printf "%s" "$*" | grep -q "^\(25[0-5]\|2[0-4][0-9]\|[01]\?[0-9][0-9]\?\)\.\(25[0-5]\|2[0-4][0-9]\|[01]\?[0-9][0-9]\?\)\.\(25[0-5]\|2[0-4][0-9]\|[01]\?[0-9][0-9]\?\)\.\(25[0-5]\|2[0-4][0-9]\|[01]\?[0-9][0-9]\?\)\(\(/[12][0-9]\|/3[210]\|/[0-9]\)\|\(:[0-5]\?[0-9]\{0,4\}$\|:6[0-5][0-5][0-3][0-5]$\)\)\?$";
    then return 0; else return 1; fi
  else
    return 1
  fi
}

conf_wireguard_ipv4_only() {
  # $1 : conf file name
  # $2->remaining : line beginnings to search for, ie "AllowedIPs"
  # $2 Default: (Address DNS AllowedIPs Endpoint)
  if [ ! -f "$1" ]; then return 1; fi
  local conf_file="$1"
  local strings=( )
  local temp_strings=( )
  if [ "$2" != "" ]; then
    shift
    strings=("$@")
  else
    IFS=',' read -ra rstrings <<< "${WG_CONF_IPV4_LINES}"
    for tstring in "${rstrings[@]}"; do
      tstring="$(echo "$tstring" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')"
      if [ "$tstring" != "" ]; then
        temp_strings+=("$tstring");
      fi
    done
    # assign what was found to the main variable
    strings+=("${temp_strings[@]}")
  fi
  if [ "" == "$strings" ]; then return 1; fi
  for str in "${strings[@]}"; do
    # grep for the line starting with $str stipping any following '=', tab and space characters
    # ie. if $str == "Address" and the line is "Address = 1.1.1.1/24,ffff:aaaa:eeee:ffff::3:aaa6/128"
    #     then $line will have the value of "1.1.1.1/24,ffff:aaaa:eeee:ffff::3:aaa6/128"
    # local line="$(cat "$conf_file" | grep "^[\t ]*$str[\t ]*=[\t ]*" | sed "s~^[\t ]*$str[\t=\ ]*~~")"
    local line="$(cat "$conf_file" | sed -n "/^[\t ]*$str[\t ]*=[\t ]*/s/^[\t ]*$str[\t ]*=[\t ]*//p")"
    if [ "" == "$line" ]; then continue; fi
    # split the CSV into an array
    local temp=()
    IFS=',' read -t 5 -r -a temp <<< "$line"
    # if the first element equals the entire line, skip and continue
    if [ "${temp[0]}" == "$line" ]; then continue; fi
    local keepers=()
    for el in "${temp[@]}"; do
      # keep only valid ipv4's
      util_is_ipv4 "$el"
      if [ $? == 0 ]; then
        keepers+=("$el");
      fi
    done
    if [ "$keepers" != "" ]; then
      # turn the array into a CSV string
      keepers="$(IFS=, ; echo "${keepers[*]}")"
      # replace the entire line with the filtered keeper ipv4's
      iprint "Stripping ipv6 from: $str = $line"
      sed -i "s~^[\t ]*$str[\t ]*=[\t ]*.*$~$str = $keepers~" "$conf_file"
    fi
  done
  return 0
}

if [ "openvpn" == "${VPN_TYPE}" ]; then
  IFS=',' read -ra vpn_options <<< "${VPN_OPTIONS}"
  if is_true "$OVPN_NO_CRED_FILE"; then
    exec openvpn --pull-filter ignore route-ipv6 --pull-filter ignore ifconfig-ipv6 \
      --config "${VPN_CONFIG}" "${vpn_options[@]}" --auth-user-pass <(printf "%s\n%s" "$VPN_USERNAME" "$VPN_PASSWORD") &
  else
    exec openvpn --pull-filter ignore route-ipv6 --pull-filter ignore ifconfig-ipv6 --config "${VPN_CONFIG}" "${vpn_options[@]}" &
  fi
elif [ "wireguard" == "${VPN_TYPE}" ]; then
  if ip link | grep -q `basename -s .conf "$VPN_CONFIG"`; then
    # TODO: fix this, it shouldn't be based on sleep x, it should be based on status
    # Run wg-quick down as an extra safeguard in case WireGuard is still up for some reason
    wg-quick down "$VPN_CONFIG" || iprint "$(basename "$0"): WireGuard is down already"
    sleep 1 # Just to give WireGuard a bit to go down
  fi
  if is_true "$WG_CONF_IPV4_ONLY"; then
    source "/scripts/network.bash"
    conf_wireguard_ipv4_only "$VPN_CONFIG"
  fi
  wg-quick up "$VPN_CONFIG"
else
  eprint "$(basename "$0"): VPN type was not understood, received: ${VPN_TYPE}"
fi
