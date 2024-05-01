#!/bin/bash

source "/etc/qbittorrent/qbt_utils.bash"

iptables_check_values() {
  # $1 = LAN_NETWORK
  # $2 = ADDITIONAL_PORTS
  # returns 0 on success, 1 on failure

  if [[ -z "$docker_interface" \
	|| -z $lan_network_list \
	|| "$VPN_DEVICE_TYPE" != "tun0" \
	&& "$VPN_DEVICE_TYPE" != "wg0" \
	&& "$VPN_DEVICE_TYPE" != "tap0" \
	|| "$VPN_PROTOCOL" != "udp" \
	&& "$VPN_PROTOCOL" != "tcp" ]] \
	|| ! is_ip "$docker_ip" \
	|| ! is_ip "$docker_mask" \
	|| ! is_ip "$docker_network_cidr" \
	|| ! is_ip "$default_gateway" \
	|| ! is_port "$VPN_PORT" \
	|| ! is_port "$QBT_WEBUI_PORT" \
	|| ! is_port "$QBT_TORRENTING_PORT"; then
		eprint "$ME: One of the below required network values was empty or incorrect."
		eprint "$ME:    docker_interface: $docker_interface"
		eprint "$ME:           docker_ip: $docker_ip"
		eprint "$ME:         docker_mask: $docker_mask"
		eprint "$ME: docker_network_cidr: $docker_network_cidr"
		eprint "$ME:     default_gateway: $default_gateway"
		eprint "$ME:    lan_network_list: $lan_network_list"
		eprint "$ME:     VPN_DEVICE_TYPE: $VPN_DEVICE_TYPE"
		eprint "$ME:        VPN_PROTOCOL: $VPN_PROTOCOL"
		eprint "$ME:            VPN_PORT: $VPN_PORT"
		eprint "$ME:      QBT_WEBUI_PORT: $QBT_WEBUI_PORT"
		eprint "$ME: QBT_TORRENTING_PORT: $QBT_TORRENTING_PORT"
		return 1
	fi
	iprint "$(print_column "Docker interface" "${docker_interface}")"
	iprint "$(print_column "Docker IP" "${docker_ip}")"
	iprint "$(print_column "Docker netmask" "${docker_mask}")"
	iprint "$(print_column "Docker network CIDR" "${docker_network_cidr}")"
	iprint "$(print_column "Default gateway" "${default_gateway}")"
  iprint "$(print_column LAN_NETWORK "\'$lan_network_list\'")"
  iprint "$(print_column ADDITIONAL_PORTS "\'$additional_port_list\'")"
  return 0
}
if ! (return 0 2>/dev/null); then
  iptables_check_values "$@";
  exit $?;
fi
