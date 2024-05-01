#!/bin/bash
# Forked from binhex's OpenVPN dockers

source "/etc/qbittorrent/qbt_utils.bash"

ME="$(basename "$0")"

configure_iptables() {

  # need to pass in these 8
  # VPN_TYPE
  # VPN_CONFIG
  # LAN_NETWORK
  # ADDITIONAL_PORTS
	# QBT_WEBUI_PORT
	# QBT_TORRENTING_PORT
  # START_PID
  # IPTABLE_MANGLE

  source "/etc/qbittorrent/iptables_parse_vpn_values.bash"
  ! iptables_parse_vpn_values "$VPN_TYPE" "$VPN_CONFIG" && kill -SIGTERM $START_PID

	source "/etc/qbittorrent/iptables_parse_docker_network_values.bash"
	iptables_parse_docker_network_values

	# # The below json example works. Using json can relieve the need of global
	# # variables to help create tests... if I make tests :-/
	# opts="{}"
	# opts="$("/etc/qbittorrent/json_iptables_parse_vpn_values.bash" "$VPN_TYPE" "$VPN_CONFIG" "$opts")" || kill -SIGTERM $START_PID
	# echo "$opts"
	#
	# opts="$("/etc/qbittorrent/json_iptables_parse_docker_network_values.bash" "$opts")" || kill -SIGTERM $START_PID
	# echo "$opts"
	#
	# declare -A data=()
	# json_to_array data "$opts"
	# echo "${data[VPN_PROTOCOL]}"

  IFS=',' read -ra _networks <<< "${LAN_NETWORK}"
  for _network in "${_networks[@]}"; do
    _network=$(trim "${_network}")
    is_ip "$_network" && export lan_network_list="$(trim "$_network $lan_network_list")"
  done

  # clean and validate optional additional port list for scripts or container linking
  IFS=',' read -ra _ports <<< "${ADDITIONAL_PORTS}"
  for _port in "${_ports[@]}"; do
    _port=$(trim "${_port}")
    is_port "$_port" && export additional_port_list="$(trim "$_port $additional_port_list")"
  done

  source "/etc/qbittorrent/iptables_check_values.bash"
  ! iptables_check_values "$LAN_NETWORK" "$ADDITIONAL_PORTS" \
		&& kill -SIGTERM $START_PID \
		&& exit

	# ip route
	###

	iptable_mangle_exit_code=;
	if is_true $IPTABLE_MANGLE; then
		# check we have iptable_mangle, if so setup fwmark
		lsmod | grep iptable_mangle
		export iptable_mangle_exit_code=$?
	fi

	trap "kill -SIGTERM $START_PID && exit" EXIT
	set -e

	# process lan networks in the list
	for lan_network_item in $lan_network_list; do
    # Without checking for existing routes, you can get "RTNETLINK answers: File exists"
    temp="$(ip route show $lan_network_item)"
    if [ ! -z "$temp" ]; then
      wprint "Route seems to exists. 'ip route show $lan_network_item' shows: $temp"
      continue
    fi
		iprint "Adding ${lan_network_item} as route via docker ${docker_interface}"
		ip route add "${lan_network_item}" via "${default_gateway}" dev "${docker_interface}"
	done

	iprint "ip route defined as:"
	echo "--------------------"
	ip route
	echo "--------------------"

	if [[ $iptable_mangle_exit_code == 0 ]]; then
		iprint "iptable_mangle support detected, adding fwmark for tables"
		# setup route for qBittorrent webui using set-mark to route
		# traffic for $QBT_WEBUI_PORT and $_qbt_torrenting_port to "${docker_interface}"
		iprint "Running: echo \"$QBT_WEBUI_PORT    webui\" >> /etc/iproute2/rt_tables"
		echo "$QBT_WEBUI_PORT    webui" >> /etc/iproute2/rt_tables
		iprint "Running: echo \"$QBT_TORRENTING_PORT    webui\" >> /etc/iproute2/rt_tables"
		echo "$QBT_TORRENTING_PORT   webui" >> /etc/iproute2/rt_tables
		iprint "Running: ip rule add fwmark 1 table webui"
		ip rule add fwmark 1 table webui
		iprint "Running: ip route add default via ${default_gateway} table webui"
		ip route add default via ${default_gateway} table webui
	fi

	# input iptable rules
	###

	# set policy to drop ipv4 for input
	iptables -P INPUT DROP

	# set policy to drop ipv6 for input
	ip6tables -P INPUT DROP 1>&- 2>&-

	# accept input to tunnel adapter
	iptables -A INPUT -i "${VPN_DEVICE_TYPE}" -j ACCEPT

	# accept input to/from LANs (172.x range is internal dhcp)
	iptables -A INPUT -s "${docker_network_cidr}" -d "${docker_network_cidr}" -j ACCEPT

	# accept input to vpn gateway
	iptables -A INPUT -i "${docker_interface}" -p $VPN_PROTOCOL --sport $VPN_PORT -j ACCEPT

	# accept input to qBittorrent webui port
	iptables -A INPUT -i "${docker_interface}" -p tcp --dport $QBT_WEBUI_PORT -j ACCEPT
	iptables -A INPUT -i "${docker_interface}" -p tcp --sport $QBT_WEBUI_PORT -j ACCEPT

	# process additional ports in list for scripts or container linking
  for additional_port_item in $additional_port_list; do
		iprint "Adding additional incoming port ${additional_port_item} for ${docker_interface}"
		# accept input to additional port for "${docker_interface}"
		iptables -A INPUT -i "${docker_interface}" -p tcp --dport "${additional_port_item}" -j ACCEPT
		iptables -A INPUT -i "${docker_interface}" -p tcp --sport "${additional_port_item}" -j ACCEPT
	done

	# accept input icmp (ping)
	iptables -A INPUT -p icmp --icmp-type echo-reply -j ACCEPT

	# accept input to local loopback
	iptables -A INPUT -i lo -j ACCEPT

	# output iptable rules
	###

	# set policy to drop ipv4 for output
	iptables -P OUTPUT DROP

	# set policy to drop ipv6 for output
	ip6tables -P OUTPUT DROP 1>&- 2>&-

	# accept output from tunnel adapter
	iptables -A OUTPUT -o "${VPN_DEVICE_TYPE}" -j ACCEPT

	# accept output to/from LANs
	iptables -A OUTPUT -s "${docker_network_cidr}" -d "${docker_network_cidr}" -j ACCEPT

	# accept output from vpn gateway
	iptables -A OUTPUT -o "${docker_interface}" -p $VPN_PROTOCOL --dport $VPN_PORT -j ACCEPT

	# if iptable mangle is available (kernel module) then use mark
	if [[ $iptable_mangle_exit_code == 0 ]]; then
		# accept output from qBittorrent webui port - used for external access
		iptables -t mangle -A OUTPUT -p tcp --dport $QBT_WEBUI_PORT -j MARK --set-mark 1
		iptables -t mangle -A OUTPUT -p tcp --sport $QBT_WEBUI_PORT -j MARK --set-mark 1
	fi

	# accept output from qBittorrent webui port - used for lan access
	iptables -A OUTPUT -o "${docker_interface}" -p tcp --dport $QBT_WEBUI_PORT -j ACCEPT
	iptables -A OUTPUT -o "${docker_interface}" -p tcp --sport $QBT_WEBUI_PORT -j ACCEPT

	# process additional ports in list for scripts or container linking
  for additional_port_item in $additional_port_list; do
		iprint "Adding additional outgoing port ${additional_port_item} for ${docker_interface}"
		# accept output to additional port for lan interface
		iptables -A OUTPUT -o "${docker_interface}" -p tcp --dport "${additional_port_item}" -j ACCEPT
		iptables -A OUTPUT -o "${docker_interface}" -p tcp --sport "${additional_port_item}" -j ACCEPT
	done

	# accept output for icmp (ping)
	iptables -A OUTPUT -p icmp --icmp-type echo-request -j ACCEPT

	# accept output from local loopback adapter
	iptables -A OUTPUT -o lo -j ACCEPT
	
	trap - EXIT
	set +e

	iprint "iptables defined as:"
	echo "--------------------"
	iptables -S
	echo "--------------------"

	return 0
}

if ! (return 0 2>/dev/null); then
  configure_iptables "$@";
  exit $?;
fi

