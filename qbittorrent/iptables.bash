#!/bin/bash
# Forked from binhex's OpenVPN dockers

source "/scripts/printers.bash"

is_true() {
  # in the below I see a floppy eared dog
  if [[ ! -z "$1" \
  && "${1}" == "1" \
  || "${1,,}" == "true" \
  || "${1,,}" == "yes" \
  || "${1,,}" == "on" ]];
  then return 0; fi
  return 1;
}

# Wait until the tunnel is up, hopefully before $REAP_WAIT.
while : ; do
	tunnelstat=$(netstat -ie | grep "tun\|tap\|wg")
	if [[ ! -z "${tunnelstat}" ]]; then
		iprint "Connection found, killing reaper ($REAPER_PID)"
		kill -9 $REAPER_PID
		break
	else
		sleep 2
	fi
done

# identify docker bridge interface name (probably eth0)
docker_interface=$(netstat -ie | grep -vE "lo|tun|tap|wg" | sed -n '1!p' | grep -P -o -m 1 '^[\w]+')
iprint "Docker interface defined as ${docker_interface}"

# identify ip for docker bridge interface
docker_ip=$(ifconfig "${docker_interface}" | grep -o "inet [0-9]*\.[0-9]*\.[0-9]*\.[0-9]*" | grep -o "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*")
iprint "Docker IP defined as ${docker_ip}"

# identify netmask for docker bridge interface
docker_mask=$(ifconfig "${docker_interface}" | grep -o "netmask [0-9]*\.[0-9]*\.[0-9]*\.[0-9]*" | grep -o "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*")
iprint "Docker netmask defined as ${docker_mask}"

# convert netmask into cidr format
docker_network_cidr=$(ipcalc "${docker_ip}" "${docker_mask}" | grep -P -o -m 1 "(?<=Network:)\s+[^\s]+" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
iprint "Docker network defined as ${docker_network_cidr}"

# ip route
###

# get default gateway of interfaces as looping through them
default_gateway=$(ip -4 route list 0/0 | cut -d ' ' -f 3)
iprint "Default gateway defined as ${default_gateway}"

# split comma separated string into list from LAN_NETWORK env variable
IFS=',' read -ra lan_network_list <<< "${LAN_NETWORK}"
iprint "LAN network list defined as ${lan_network_list[@]}"

if [[ -z "$docker_interface" \
|| -z "$docker_ip" \
|| -z "$docker_mask" \
|| -z "$docker_network_cidr" \
|| -z "$default_gateway" \
|| -z "$lan_network_list" \
|| -z "$VPN_DEVICE_TYPE" \
|| -z "$VPN_PROTOCOL" \
|| ! $VPN_PORT =~ ^[\ \t]*[0-9]+[\ \t]*$ \
|| ! $QBT_WEBUI_PORT =~ ^[\ \t]*[0-9]+[\ \t]*$ \
|| ! $QBT_TORRENTING_PORT =~ ^[\ \t]*[0-9]+[\ \t]*$ ]]; then
  eprint "$(basename "$0"): One of the below required network values was empty or incorrect."
  eprint "$(basename "$0"):    docker_interface: $docker_interfaace"
  eprint "$(basename "$0"):           docker_ip: $docker_ip"
  eprint "$(basename "$0"):         docker_mask: $docker_mask"
  eprint "$(basename "$0"): docker_network_cidr: $docker_network_cidr"
  eprint "$(basename "$0"):     default_gateway: $default_gateway"
  eprint "$(basename "$0"):    lan_network_list: ${lan_network_list[@]}"
  eprint "$(basename "$0"):     VPN_DEVICE_TYPE: $VPN_DEVICE_TYPE"
  eprint "$(basename "$0"):        VPN_PROTOCOL: $VPN_PROTOCOL"
  eprint "$(basename "$0"):            VPN_PORT: $VPN_PORT"
  eprint "$(basename "$0"):      QBT_WEBUI_PORT: $QBT_WEBUI_PORT"
  eprint "$(basename "$0"): QBT_TORRENTING_PORT: $QBT_TORRENTING_PORT"
  printf "%s\n" "BYE"
  exit 1
fi

# process lan networks in the list
for lan_network_item in "${lan_network_list[@]}"; do
	# strip whitespace from start and end of lan_network_item
	lan_network_item=$(echo "${lan_network_item}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')

	iprint "Adding ${lan_network_item} as route via docker ${docker_interface}"
	ip route add "${lan_network_item}" via "${default_gateway}" dev "${docker_interface}"
done

iprint "ip route defined as follows..."
echo "--------------------"
ip route
echo "--------------------"

# setup iptables marks to allow routing of defined ports via "${docker_interface}"
###

if [[ "${DEBUG}" == "true" ]]; then
	vprint "[DEBUG] Modules currently loaded for kernel"
	lsmod
fi

# check we have iptable_mangle, if so setup fwmark
lsmod | grep iptable_mangle
iptable_mangle_exit_code=$?

_vpn_port=$(echo "${VPN_PORT}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
_qbt_webui_port=$(echo "${QBT_WEBUI_PORT}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
_qbt_torrenting_port=$(echo "${QBT_TORRENTING_PORT}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')

if [[ $iptable_mangle_exit_code == 0 ]]; then
	iprint "iptable_mangle support detected, adding fwmark for tables"

	# setup route for qBittorrent webui using set-mark to route
  # traffic for $_qbt_webui_port and $_qbt_torrenting_port to "${docker_interface}"
	echo "$_qbt_webui_port    webui" >> /etc/iproute2/rt_tables
	echo "$_qbt_torrenting_port   webui" >> /etc/iproute2/rt_tables
	ip rule add fwmark 1 table webui
	ip route add default via ${default_gateway} table webui
fi

set -e

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
iptables -A INPUT -i "${docker_interface}" -p $VPN_PROTOCOL --sport $_vpn_port -j ACCEPT

# accept input to qBittorrent webui port
iptables -A INPUT -i "${docker_interface}" -p tcp --dport $_qbt_webui_port -j ACCEPT
iptables -A INPUT -i "${docker_interface}" -p tcp --sport $_qbt_webui_port -j ACCEPT

# additional port list for scripts or container linking
if [[ ! -z "${ADDITIONAL_PORTS}" ]]; then
	# split comma separated string into list from ADDITIONAL_PORTS env variable
	IFS=',' read -ra additional_port_list <<< "${ADDITIONAL_PORTS}"

	# process additional ports in the list
	for additional_port_item in "${additional_port_list[@]}"; do

		# strip whitespace from start and end of additional_port_item
		additional_port_item=$(echo "${additional_port_item}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')

		iprint "Adding additional incoming port ${additional_port_item} for ${docker_interface}"

		# accept input to additional port for "${docker_interface}"
		iptables -A INPUT -i "${docker_interface}" -p tcp --dport "${additional_port_item}" -j ACCEPT
		iptables -A INPUT -i "${docker_interface}" -p tcp --sport "${additional_port_item}" -j ACCEPT
	done
fi

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
iptables -A OUTPUT -o "${docker_interface}" -p $VPN_PROTOCOL --dport $_vpn_port -j ACCEPT

# if iptable mangle is available (kernel module) then use mark
if [[ $iptable_mangle_exit_code == 0 ]]; then
	# accept output from qBittorrent webui port - used for external access
	iptables -t mangle -A OUTPUT -p tcp --dport $_qbt_webui_port -j MARK --set-mark 1
	iptables -t mangle -A OUTPUT -p tcp --sport $_qbt_webui_port -j MARK --set-mark 1
fi

# accept output from qBittorrent webui port - used for lan access
iptables -A OUTPUT -o "${docker_interface}" -p tcp --dport $_qbt_webui_port -j ACCEPT
iptables -A OUTPUT -o "${docker_interface}" -p tcp --sport $_qbt_webui_port -j ACCEPT

# additional port list for scripts or container linking
if [[ ! -z "${ADDITIONAL_PORTS}" ]]; then
	# split comma separated string into list from ADDITIONAL_PORTS env variable
	IFS=',' read -ra additional_port_list <<< "${ADDITIONAL_PORTS}"

	# process additional ports in the list
	for additional_port_item in "${additional_port_list[@]}"; do

		# strip whitespace from start and end of additional_port_item
		additional_port_item=$(echo "${additional_port_item}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')

		iprint "Adding additional outgoing port ${additional_port_item} for ${docker_interface}"

		# accept output to additional port for lan interface
		iptables -A OUTPUT -o "${docker_interface}" -p tcp --dport "${additional_port_item}" -j ACCEPT
		iptables -A OUTPUT -o "${docker_interface}" -p tcp --sport "${additional_port_item}" -j ACCEPT

	done
fi

# accept output for icmp (ping)
iptables -A OUTPUT -p icmp --icmp-type echo-request -j ACCEPT

# accept output from local loopback adapter
iptables -A OUTPUT -o lo -j ACCEPT

set +e

iprint "iptables defined as:"
echo "--------------------"
iptables -S
echo "--------------------"
