#!/bin/bash

source "/etc/qbittorrent/qbt_utils.bash"

ME="$(basename "$0")"

iptables_parse_docker_network_values() {
  # $@ None
  # returns 0 on success, 1 on failure
  
  # Get Docker network values.
  # identify docker bridge interface name (probably eth0)
	export docker_interface=$(netstat -ie | grep -vE "lo|tun|tap|wg" | sed -n '1!p' | grep -P -o -m 1 '^[\w]+')
	export docker_ip=$(ifconfig "${docker_interface}" | grep -o "inet [0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+" | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+")
	export docker_mask=$(ifconfig "${docker_interface}" | grep -o "netmask [0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+" | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+")
	export docker_network_cidr="$(trim "$(ipcalc "$docker_ip" "$docker_mask" | grep -P -o -m 1 "(?<=Network:)\s+[^\s]+")")"
	export default_gateway=$(ip -4 route list 0/0 | cut -d ' ' -f 3)

  if [[ ! -z "$docker_interface" ]] \
	&& is_ip "$docker_ip" \
	&& is_ip "$docker_mask" \
	&& is_ip "$docker_network_cidr" \
	&& is_ip "$default_gateway"; then
		return 0
	fi
  # eprint "$ME: One of the below Docker network values was empty or incorrect."
  # eprint "$ME:    docker_interface: $docker_interface"
  # eprint "$ME:           docker_ip: $docker_ip"
  # eprint "$ME:         docker_mask: $docker_mask"
  # eprint "$ME: docker_network_cidr: $docker_network_cidr"
  # eprint "$ME:     default_gateway: $default_gateway"
  return 1
}

if ! (return 0 2>/dev/null); then
  iptables_parse_docker_network_values "$@";
  exit $?;
fi
