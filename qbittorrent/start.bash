#!/bin/bash

source "/scripts/printers.bash"

if [[ ! -f "/usr/share/zoneinfo/$TZ" ]]; then
  export TZ="Etc/UTC"
fi
echo "$TZ" > /etc/timezone

export START_TIME="$(date +%s)"

ME="$(basename "$0")"

is_true() {
  if [[ ! -z "$1" \
  && "${1}" == "1" \
  || "${1,,}" == "true" \
  || "${1,,}" == "yes" \
  || "${1,,}" == "on" ]];
  then return 0; fi
  return 1;
}

if [[ -z "${REAP_WAIT}" ]]; then
  export REAP_WAIT=30
fi

# If the VPN connects under REAPER_WAIT, the sleep process is killed.
sleep $REAP_WAIT && kill -10 $$ &
export REAPER_PID=$(pgrep -P $!)

exiting() {
	if [ "" != "$*" ]; then
		eprint "$ME: $*";
		if is_true "$VPN_CONF_SWITCH" && [ -f "/etc/qbittorrent/vpn_conf_switch.bash" ]; then
			/etc/qbittorrent/vpn_conf_switch.bash "$VPN_TYPE" "$CONFIG_DIR"
		fi
	fi
	# Docker wants at least 10 seconds between restarts or spam rules invoke
  while [ $(($(date +%s)-$START_TIME)) -lt 11 ]; do
    sleep 1;
  done
	kill -s 9 -- -1
	iprint "BYE"
  exit 1
}
trap "exiting Reaped! Did not connect to the VPN under $REAP_WAIT seconds, restarting." SIGUSR1

# the help needs to be written out regardless of everything
if [ -f "/scripts/README.md" ]; then
	# copy the Readme.md to /config but don't overwrite it
  cp "/scripts/README.md" "/config" &> /dev/null
  chown "${PUID}":"${PGID}" "/config/README.md" &> /dev/null
  chmod 664 "/scripts/README.md" &> /dev/null
fi

# copy supplemental torrent/magnet script
if [ -f "/scripts/torrent_or_magnet_forward.bash" ]; then
	# copy to /config but don't overwrite if exists
  cp "/scripts/torrent_or_magnet_forward.bash" "/config" &> /dev/null
  chown "${PUID}":"${PGID}" "/config/torrent_or_magnet_forward.bash" &> /dev/null
  chmod 774 "/scripts/torrent_or_magnet_forward.bash" &> /dev/null
fi

# may be needed if not using --device==/dev/net/tun or ---privileged
if [ ! -c /dev/net/tun ]; then
	mkdir -p /dev/net;
	mknod /dev/net/tun c 10 200
	chmod 600 /dev/net/tun
fi

# check for presence of network interface docker0
check_network=$(ifconfig | grep docker0 || true)
# if network interface docker0 is present then we are running in host mode and thus must exit
if [[ ! -z "${check_network}" ]]; then
	eprint "$ME: Network type detected as 'Host', this will cause major issues, please stop the container and switch back to 'Bridge' mode"
	exiting
fi

iprint "Reaper ($REAPER_PID) waits $REAP_WAIT seconds before kill -10 $$."

iprint "          REAP_WAIT: ${REAP_WAIT}"

iprint "                 TZ: $TZ"

if [[ -z "${MOVE_CONFIGS}" ]]; then
  export MOVE_CONFIGS=0
fi
iprint "       MOVE_CONFIGS: ${MOVE_CONFIGS}"

if [[ -z "${OVPN_NO_CRED_FILE}" ]]; then
  export OVPN_NO_CRED_FILE=0
fi
iprint "  OVPN_NO_CRED_FILE: ${OVPN_NO_CRED_FILE}"

if [[ -z "${QBT_TORRENTING_PORT}" ]]; then
	export QBT_TORRENTING_PORT=8999
fi
iprint "QBT_TORRENTING_PORT: ${QBT_TORRENTING_PORT}"

# if the port is changed within qBittorent itself, the WebUI might be unreachable
if [[ -z "${QBT_WEBUI_PORT}" ]]; then
	export QBT_WEBUI_PORT=8080
fi
iprint "     QBT_WEBUI_PORT: ${QBT_WEBUI_PORT}"

if [[ -z "${_QBT_USERNAME}" ]]; then
	export _QBT_USERNAME="admin"
fi
iprint "      _QBT_USERNAME: ${_QBT_USERNAME}"

if [[ -z "${_QBT_PASSWORD}" ]]; then
	export _QBT_PASSWORD="adminadmin"
fi
iprint "      _QBT_PASSWORD: ${_QBT_PASSWORD}"

if [[ -z "${QBT_SET_INTERFACE}" ]]; then
	export QBT_SET_INTERFACE=1
fi
iprint "  QBT_SET_INTERFACE: ${QBT_SET_INTERFACE}"

# NOTE: if "/config/${VPN_TYPE}_confs" is empty or non-existent, then the
# functionally of VPN_CONF_SWITCH does nothing besides print a message.
if [[ -z "${VPN_CONF_SWITCH}" ]]; then
	export VPN_CONF_SWITCH=1;
fi
iprint "    VPN_CONF_SWITCH: ${VPN_CONF_SWITCH}"

if [[ -z "${WG_CONF_IPV4_ONLY}" ]]; then
	export WG_CONF_IPV4_ONLY=1
fi
iprint "  WG_CONF_IPV4_ONLY: ${WG_CONF_IPV4_ONLY}"

if [[ -z "${WG_CONF_IPV4_LINES}" ]]; then
	export WG_CONF_IPV4_LINES="Address,DNS,AllowedIPs,Endpoint"
fi
iprint " WG_CONF_IPV4_LINES: ${WG_CONF_IPV4_LINES}"

if [[ -z "${SHUTDOWN_WAIT}" ]]; then
	export  SHUTDOWN_WAIT=30
fi
iprint "      SHUTDOWN_WAIT: ${SHUTDOWN_WAIT}"

if [[ -z "${VPN_DOWN_FILE}" ]]; then
  export  VPN_DOWN_FILE=0
fi
iprint "      VPN_DOWN_FILE: ${VPN_DOWN_FILE}"

if [[ -z "${VPN_UP_SCRIPT}" ]]; then
  export  VPN_UP_SCRIPT=0
fi
iprint "      VPN_UP_SCRIPT: ${VPN_UP_SCRIPT}"

if [[ -z "${VPN_DOWN_SCRIPT}" ]]; then
  export  VPN_DOWN_SCRIPT=0
fi
iprint "    VPN_DOWN_SCRIPT: ${VPN_DOWN_SCRIPT}"

if [[ -z "${VPN_ENABLED}" ]]; then
  export VPN_ENABLED=1
fi
iprint "        VPN_ENABLED: ${VPN_ENABLED}"

if [[ -z "${VPN_USERNAME}" ]]; then
  export VPN_USERNAME=;
fi
iprint "       VPN_USERNAME: ${VPN_USERNAME}"

if [[ -z "${VPN_PASSWORD}" ]]; then
  export VPN_PASSWORD=;
fi
iprint "       VPN_PASSWORD: ${VPN_PASSWORD}"

if [[ -z "${VPN_OPTIONS}" ]]; then
  export VPN_OPTIONS=;
fi
iprint "        VPN_OPTIONS: ${VPN_OPTIONS}"

if [[ -z "${ADDITIONAL_PORTS}" ]]; then
  export ADDITIONAL_PORTS=;
fi
iprint "   ADDITIONAL_PORTS: ${ADDITIONAL_PORTS}"

if [[ -z "${LEGACY_IPTABLES}" ]]; then
  export LEGACY_IPTABLES=0
fi
iprint "    LEGACY_IPTABLES: ${LEGACY_IPTABLES}"

# # # strip whitespace from start and end: 's~^[ \t]*~~;s~[ \t]*$~~'

if is_true "$LEGACY_IPTABLES"; then
	iprint "Setting iptables to iptables (legacy)"
	update-alternatives --set iptables /usr/sbin/iptables-legacy
else
	iprint "Not making any changes to iptables version"
fi
iptables_version=$(iptables -V)
iprint "The container is currently running ${iptables_version}." 

if is_true "$VPN_ENABLED"; then
	# Check if VPN_TYPE is set.
  if [[ "${VPN_TYPE}" != "openvpn" && "${VPN_TYPE}" != "wireguard" ]]; then
		wprint "VPN_TYPE not set, as 'wireguard' or 'openvpn', defaulting to OpenVPN."
		export VPN_TYPE="openvpn"
	fi
  iprint "           VPN_TYPE: '${VPN_TYPE}'"


	# Create the directory to store OpenVPN or WireGuard config files
	mkdir -p /config/${VPN_TYPE}
	# Set permmissions and owner for files in /config/openvpn or /config/wireguard directory
	set +e
	chown -R "${PUID}":"${PGID}" "/config/${VPN_TYPE}" &> /dev/null
	exit_code_chown=$?
	chmod -R 775 "/config/${VPN_TYPE}" &> /dev/null
	exit_code_chmod=$?
	set -e
	if (( ${exit_code_chown} != 0 || ${exit_code_chmod} != 0 )); then
		wprint "Unable to chown and/or chmod /config/${VPN_TYPE}/"
	fi
	if is_true "$VPN_CONF_SWITCH"; then
		mkdir -p "/config/${VPN_TYPE}_confs"
		chown -R "${PUID}":"${PGID}" "/config/${VPN_TYPE}_confs" &> /dev/null
		chmod -R 775 "/config/${VPN_TYPE}_confs" &> /dev/null
	fi

  # NOTE: MOVE_CONFIGS checks start here

	if [[ "${VPN_TYPE}" == "openvpn" ]]; then
  	# Wildcard search for openvpn config files, match on first result
		export VPN_CONFIG=$(find /config/openvpn -maxdepth 1 -type f -name "*.ovpn" -print -quit)
	else
    # For wireguard, specifically match "wg0.conf"
		export VPN_CONFIG=$(find /config/wireguard -maxdepth 1 -type f -name "wg0.conf" -print -quit)
	fi

	# If MOVE_CONFIGS is enabled, move the config and set VPN_CONFIG to it
  if is_true "$MOVE_CONFIGS" && [ ! -z "$VPN_CONFIG" ]; then
		iprint "MOVE_CONFIGS is enabled, moving $VPN_CONFIG to /vpn_files/$VPN_TYPE"
		export VPN_CONFIG="/vpn_files/$VPN_TYPE/$(basename "${VPN_CONFIG}")"
  fi

	# If VPN_CONFIG is still empty, check inside the container
  if is_true "$MOVE_CONFIGS" && [ -z "$VPN_CONFIG" ]; then
    if [[ "${VPN_TYPE}" == "openvpn" ]]; then
      export VPN_CONFIG=$(find /vpn_files/openvpn -maxdepth 1 -type f -name "*.ovpn" -print -quit)
    else
      export VPN_CONFIG=$(find /vpn_files/wireguard -maxdepth 1 -type f -name "wg0.conf" -print -quit)
    fi
  fi

  # When MOVE_CONFIGS is enabled, the working parent dir becomes "/vpn_files"
  # instead of the default "/config".
  export CONFIG_DIR="$(dirname "$(dirname "$VPN_CONFIG")")"

	# Exit if there's no config files found in /config/openvpn or /config/wireguard
	if [[ -z "${VPN_CONFIG}" ]]; then
    if is_true "$MOVE_CONFIGS"; then
      temp_txt=" or /vpn_files/$VPN_TYPE/"
    fi
		if [[ "${VPN_TYPE}" == "openvpn" ]]; then
			eprint "$ME: No OpenVPN config file found in /config/openvpn/$temp_txt. Make sure the file extension is '.ovpn'"
		else
			eprint "$ME: No WireGuard config file found in /config/wireguard/$temp_txt. Make sure the file name is 'wg0.conf'"
		fi
    exiting
	fi

  # If MOVE_CONFIGS is enabled, copy the files into the container
	# Note: The source files are removed
  if is_true "$MOVE_CONFIGS"; then
		if [ ! -z "$(ls -A "/config/$VPN_TYPE/" 2> /dev/null)" ]; then
      iprint "MOVE_CONFIGS is enabled, removing files in \"/config/$VPN_TYPE/\"*"

      rm -rf "/vpn_files/$VPN_TYPE"
			mkdir -p "/vpn_files/$VPN_TYPE"

			cp -vafT "/config/$VPN_TYPE/" "/vpn_files/$VPN_TYPE"

      shopt -s dotglob
			rm -vrf "/config/${VPN_TYPE}/"*
			shopt -u dotglob
		fi
		if is_true "$VPN_CONF_SWITCH" \
		&& [ ! -z "$(ls -A "/config/${VPN_TYPE}_confs/" 2> /dev/null)" ]; then
      iprint "MOVE_CONFIGS is enabled, removing files in \"/config/${VPN_TYPE}_confs/\"*"

      rm -rf "/vpn_files/${VPN_TYPE}_confs"
			mkdir -p "/vpn_files/${VPN_TYPE}_confs"

			cp -vafT "/config/${VPN_TYPE}_confs/" "/vpn_files/${VPN_TYPE}_confs"

			shopt -s dotglob
			rm -vrf "/config/${VPN_TYPE}_confs/"*
			shopt -u dotglob
		fi
  fi

	# Read username and password env vars and put them in credentials.conf, then add ovpn config for credentials file
	if ! is_true "$OVPN_NO_CRED_FILE" && [[ "${VPN_TYPE}" == "openvpn" ]]; then
		if [[ ! -z "${VPN_USERNAME}" ]] && [[ ! -z "${VPN_PASSWORD}" ]]; then

      if is_true "$MOVE_CONFIGS"; then
      	if [[ ! -e /vpn_files/openvpn/credentials.conf ]]; then
				  touch /vpn_files/openvpn/credentials.conf
			  fi
        printf "%s\n" "${VPN_USERNAME}" > /vpn_files/openvpn/credentials.conf
			  printf "%s\n" "${VPN_PASSWORD}" >> /vpn_files/openvpn/credentials.conf
      else
      	if [[ ! -e /config/openvpn/credentials.conf ]]; then
				  touch /config/openvpn/credentials.conf
			  fi
        printf "%s\n" "${VPN_USERNAME}" > /config/openvpn/credentials.conf
        printf "%s\n" "${VPN_PASSWORD}" >> /config/openvpn/credentials.conf
      fi

			# Replace line with one that points to credentials.conf
			auth_cred_exist=$(cat "${VPN_CONFIG}" | grep -m 1 'auth-user-pass')
			if [[ ! -z "${auth_cred_exist}" ]]; then
				# Get line number of auth-user-pass
				LINE_NUM=$(grep -Fn -m 1 'auth-user-pass' "${VPN_CONFIG}" | cut -d: -f 1)
				sed -i "${LINE_NUM}s/.*/auth-user-pass credentials.conf/" "${VPN_CONFIG}"
			else
				sed -i "1s/^/auth-user-pass credentials.conf\n/" "${VPN_CONFIG}"
			fi
		fi
	fi

  # NOTE: MOVE_CONFIGS checks end here

	# convert CRLF (windows) to LF (unix) for ovpn
	dos2unix "${VPN_CONFIG}" 1> /dev/null

	if is_true "$OVPN_NO_CRED_FILE" && "${VPN_TYPE}" == "openvpn" ]]; then
		# remove all lines starting with "auth-user-pass "
    iprint "Stripping lines beginning with: \"auth-user-pass \""
		sed -i '/^auth-user-pass .*/d' "${VPN_CONFIG}"
	fi
	
	# parse values from the ovpn or conf file
	if [[ "${VPN_TYPE}" == "openvpn" ]]; then
		export vpn_remote_line=$(cat "${VPN_CONFIG}" | grep -P -o -m 1 '(?<=^remote\s)[^\n\r]+' | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
	else
		export vpn_remote_line=$(cat "${VPN_CONFIG}" | grep -P -o -m 1 '(?<=^Endpoint)(\s{0,})[^\n\r]+' | sed -e 's~^[=\ ]*~~')
	fi

	if [[ -z "${vpn_remote_line}" ]]; then
		eprint "$ME: VPN configuration file ${VPN_CONFIG} does not contain 'remote' line, showing contents of file before exit..."
		cat "${VPN_CONFIG}"
		exiting
	fi
  iprint "    VPN remote line: '${vpn_remote_line}'"

	if [[ "${VPN_TYPE}" == "openvpn" ]]; then
		export VPN_REMOTE=$(echo "${vpn_remote_line}" | grep -P -o -m 1 '^[^\s\r\n]+' | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
	else
		export VPN_REMOTE=$(echo "${vpn_remote_line}" | grep -P -o -m 1 '^[^:\r\n]+')
	fi

	if [[ -z "${VPN_REMOTE}" ]]; then
		eprint "$ME: VPN_REMOTE not found in ${VPN_CONFIG}. Exiting."
		exiting
	fi
  iprint "         VPN_REMOTE: '${VPN_REMOTE}'"

	if [[ "${VPN_TYPE}" == "openvpn" ]]; then
		export VPN_PORT=$(echo "${vpn_remote_line}" | grep -P -o -m 1 '(?<=\s)\d{2,5}(?=\s)?+' | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
	else
		export VPN_PORT=$(echo "${vpn_remote_line}" | grep -P -o -m 1 '(?<=:)\d{2,5}(?=:)?+')
	fi

	if [[ -z "${VPN_PORT}" ]]; then
		eprint "$ME: VPN_PORT not found in ${VPN_CONFIG}. Exiting."
		exiting
	fi
  iprint "           VPN_PORT: '${VPN_PORT}'"

	if [[ "${VPN_TYPE}" == "openvpn" ]]; then
		export VPN_PROTOCOL=$(cat "${VPN_CONFIG}" | grep -P -o -m 1 '(?<=^proto\s)[^\r\n]+' | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
		if [[ -z "${VPN_PROTOCOL}" ]]; then
			export VPN_PROTOCOL=$(echo "${vpn_remote_line}" | grep -P -o -m 1 'udp|tcp-client|tcp$' | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
			if [[ -z "${VPN_PROTOCOL}" ]]; then
				wprint "VPN_PROTOCOL not found in ${VPN_CONFIG}, assuming udp"
				export VPN_PROTOCOL="udp"
			fi
		fi
		# required for use in iptables
		if [[ "${VPN_PROTOCOL}" == "tcp-client" ]]; then
			export VPN_PROTOCOL="tcp"
		fi
	else
		export VPN_PROTOCOL="udp"
	fi
  iprint "       VPN_PROTOCOL: '${VPN_PROTOCOL}'"

  
	if [[ "${VPN_TYPE}" == "openvpn" ]]; then
		VPN_DEVICE_TYPE=$(cat "${VPN_CONFIG}" | grep -P -o -m 1 '(?<=^dev\s)[^\r\n\d]+' | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
		if [[ -z "${VPN_DEVICE_TYPE}" ]]; then
      eprint "$ME: VPN_DEVICE_TYPE not found in ${VPN_CONFIG}. Exiting."
			exiting
    fi
		export VPN_DEVICE_TYPE="${VPN_DEVICE_TYPE}0"
	else
    export VPN_DEVICE_TYPE="wg0"
  fi
  iprint "    VPN_DEVICE_TYPE: '${VPN_DEVICE_TYPE}'"

	# get values from env vars as defined by user
	export LAN_NETWORK=$(echo "${LAN_NETWORK}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
	if [[ -z "${LAN_NETWORK}" ]]; then
    export LAN_NETWORK="192.168.0.0/16,10.0.0.0/8"
	fi
  iprint "        LAN_NETWORK: '${LAN_NETWORK}'"

else
	wprint "!!IMPORTANT!! You have set the VPN to disabled, your connection will NOT be secure!"
fi

export NAME_SERVERS=$(echo "${NAME_SERVERS}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ -z "${NAME_SERVERS}" ]]; then
# https://www.how-to-hide-ip.net/no-logs-dns-server-free-public/
# FreeDNS: The servers are located in Austria, and you may use the following DNS IPs: 37.235.1.174 and 37.235.1.177.
# DNS.WATCH: The DNS servers are: 84.200.69.80 (IPv6: 2001:1608:10:25::1c04:b12f) and 84.200.70.40 (IPv6: 2001:1608:10:25::9249:d69b), located in Germany.
	export NAME_SERVERS="1.1.1.1,37.235.1.174,84.200.69.80,84.200.70.40,1.0.0.1,37.235.1.177"
fi
iprint "       NAME_SERVERS: '${NAME_SERVERS}'"

# split comma seperated string into list from NAME_SERVERS env variable
IFS=',' read -ra name_server_list <<< "${NAME_SERVERS}"
# process name servers in the list
for name_server_item in "${name_server_list[@]}"; do
	name_server_item=$(echo "${name_server_item}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
	iprint "Adding ${name_server_item} to resolv.conf"
	echo "nameserver ${name_server_item}" >> /etc/resolv.conf
done

if [[ -z "${PUID}" ]]; then
	export PUID="1000"
fi
iprint "               PUID: $PUID"

if [[ -z "${PGID}" ]]; then
	export PGID="1000"
fi
iprint "               PGID: $PGID"

if is_true "$VPN_ENABLED"; then
  cd "$CONFIG_DIR/$VPN_TYPE"
	iprint "Starting ${VPN_TYPE}..."
	/etc/qbittorrent/vpn_start.bash &
  wait $!
	/etc/qbittorrent/iptables.bash &
  wait $!
  exec /bin/bash /etc/qbittorrent/qbittorrent.bash
else
	wprint "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
  wprint "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
  wprint "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
	wprint "THE CONTAINER IS RUNNING WITH VPN DISABLED"
	wprint "PLEASE MAKE SURE VPN_ENABLED IS SET TO 'yes'"
	wprint "IF THIS IS INTENTIONAL, YOU CAN IGNORE THIS"
	wprint "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
  wprint "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
  wprint "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
  wprint "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
	exec /bin/bash /etc/qbittorrent/qbittorrent.bash
fi
