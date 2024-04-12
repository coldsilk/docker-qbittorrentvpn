#!/bin/bash

conf_wireguard_ipv4_only() {
  # $1 : conf file name
  # $2->remaining : line beginnings to search for, ie "AllowedIPs"
  # $2 Default: (Address DNS AllowedIPs Endpoint)
  if [ ! -f "$1" ]; then return 1; fi
  local conf_file="$1"
  local strings=(Address DNS AllowedIPs Endpoint)
  if [ "$2" != "" ]; then
    shift
    strings=("$@")
  fi
  for str in "${strings[@]}"; do
    # grep for the line starting with $str stipping any following '=', tab and space characters
    # ie. if $str == "Address" and the line is "Address = 1.1.1.1/24,ffff:aaaa:eeee:ffff::3:aaa6/128"
    #     then $line will have the value of "1.1.1.1/24,ffff:aaaa:eeee:ffff::3:aaa6/128"
    local line="$(cat "$conf_file" | grep "^[\t ]*$str[\t ]*=[\t ]*" | sed "s~^[\t ]*$str[\t=\ ]*~~")"
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
      sed -i "s~^[\t ]*$str[\t ]*=[\t ]*.*$~$str = $keepers~" "$conf_file"
    fi
  done
  return 0
}

if [ "openvpn" == "${VPN_TYPE}" ]; then
  cd /config/openvpn
  exec openvpn --pull-filter ignore route-ipv6 --pull-filter ignore ifconfig-ipv6 --config "${VPN_CONFIG}" &
elif [ "wireguard" == "${VPN_TYPE}" ]; then
  cd /config/wireguard
  if ip link | grep -q `basename -s .conf "$VPN_CONFIG"`; then
    # Run wg-quick down as an extra safeguard in case WireGuard is still up for some reason
    wg-quick down "$VPN_CONFIG" || echo "[INFO] $(basename "$0"): WireGuard is down already" | ts '%Y-%m-%d %H:%M:%.S'
    sleep 0.5 # Just to give WireGuard a bit to go down
  fi
  if [ "${WG_CONF_IPV4_ONLY}" == "1" ]; then
    . "/scripts/network.bash"
    conf_wireguard_ipv4_only "$VPN_CONFIG"
  fi
  wg-quick up "$VPN_CONFIG"
else
  echo "[ERROR] $(basename "$0"): VPN type was not understood, received: ${VPN_TYPE}" | ts '%Y-%m-%d %H:%M:%.S'
fi
