#!/bin/bash

source "/etc/qbittorrent/qbt_utils.bash"

ME="$(basename "$0")"

# if network interface docker0 is present then we are running in host mode and will exit
if ifconfig | grep docker0; then
	eprint "$ME: Network type detected as 'Host', this will cause major issues. Please switch to 'Bridge' mode. Exiting."
  printf "%s\n" "BYE"
	exit 1
fi

export TZ="$(trim "$TZ")"
if [[ ! -f "/usr/share/zoneinfo/$TZ" ]]; then
  export TZ="Etc/UTC"
fi
ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

export START_TIME="$(date +%s)"

export START_PID=$$

# Docker run wants at least 10 seconds between restarts or spamming rules are invoked.
export MIN_UPTIME=10;

exiting() {
	if [[ $(date +%s) -lt $(( $START_TIME+$MIN_UPTIME )) ]]; then
  	eprint "$ME: Exiting in $(( $MIN_UPTIME-($(date +%s)-$START_TIME) )) seconds."
	else
		eprint "$ME: Exiting."
	fi
  while [[ $(($(date +%s)-$START_TIME)) -lt $MIN_UPTIME ]]; do
    sleep 1;
  done
	killall5 -9
	printf "%s\n" "BYE"
  exit $1
}
trap "exiting" SIGTERM

exiting_switch_extra_confs() {
	if [[ "$1" == "" ]]; then
		# This is what the reaper will signal after REAPER_WAIT as been exceeded.
		eprint "$ME: Reaped! Did not connect to the VPN under $REAPER_WAIT seconds.";
	fi
	if is_true "$VPN_CONF_SWITCH" && [[ -f "/etc/qbittorrent/vpn_conf_switch.bash" ]]; then
		/etc/qbittorrent/vpn_conf_switch.bash "$VPN_TYPE" "/$(printf "%s" "$VPN_CONFIG" | cut -d '/' -f 2)"
	fi
	exiting $1
}
# trap "exiting_switch_extra_confs" SIGUSR1 # 10

export REAPER_WAIT="$(trim "${REAPER_WAIT}")"
[[ ! $REAPER_WAIT =~ ^[0-9]+$ ]] && export REAPER_WAIT=30
if [ $REAPER_WAIT != 0 ]; then
  # If the VPN connects in less than REAPER_WAIT, the reaper is killed.
  export REAPER_PID=$(reaper_spawn "$REAPER_WAIT" "SIGUSR1" "$$")
  [[ ! $REAPER_PID =~ ^[0-9]+$ ]] && eprint "Reaper failed to spawn." && exiting 1
fi
hprint "Reaper ($REAPER_PID) waits $REAPER_WAIT seconds before kill -SIGUSR1 $$."

###############################
###############################
###############################
###############################
#   ##    STARTS HERE    ##   #
###############################
###############################
###############################
###############################
        ##           ##
       ##             ##
      ##               ##
     ##                 ##
    ##                   ##
   ##                     ##
  ##                       ##
 ##                         ##
##                           ##

if [[ ! -w "/config" ]]; then
	eprint "$ME: /config is not writeable."
	exiting 1
fi

# write out the help file
if [ -f "/scripts/README.md" ]; then
	# copy the Readme.md to /config but don't overwrite it
  cp "/scripts/README.md" "/config" &> /dev/null
  chown "${PUID}":"${PGID}" "/config/README.md" &> /dev/null
  chmod 664 "/scripts/README.md" &> /dev/null
fi

source "/etc/qbittorrent/start_set_and_print_variables.bash"
start_set_and_print_variables

if is_true "$LEGACY_IPTABLES"; then
	iprint "Setting iptables to iptables (legacy)"
	update-alternatives --set iptables /usr/sbin/iptables-legacy
fi

if is_true "$VPN_ENABLED"; then
	# Check if VPN_TYPE is set.
  export VPN_TYPE=$(trim "${VPN_TYPE,,}")
  if [[ "${VPN_TYPE}" != "openvpn" && "${VPN_TYPE}" != "wireguard" ]]; then
		wprint "VPN_TYPE not set, as 'wireguard' or 'openvpn', defaulting to OpenVPN."
		export VPN_TYPE="openvpn"
	fi
  iprint "$(print_column VPN_TYPE "\'${VPN_TYPE}\'")"

  # may be needed if not using --device==/dev/net/tun or ---privileged
  if [[ "$VPN_TYPE" == "openvpn" && ! -c /dev/net/tun ]]; then
    mkdir -p /dev/net;
    mknod /dev/net/tun c 10 200
    chmod 600 /dev/net/tun
  fi

	# Create the directory to store OpenVPN or WireGuard config files
	mkdir -p /config/${VPN_TYPE}
	# Set permmissions and owner for files in /config/openvpn or /config/wireguard directory
  # NOTE: This won't work if MOVE_CONFIGS is enabled, so this will be done again later.
	chown -R "${PUID}":"${PGID}" "/config/${VPN_TYPE}" &> /dev/null
	exit_code_chown=$?
	chmod -R 775 "/config/${VPN_TYPE}" &> /dev/null
	exit_code_chmod=$?

	if (( ${exit_code_chown} != 0 || ${exit_code_chmod} != 0 )); then
		eprint "$ME: Unable to chown and/or chmod /config/${VPN_TYPE}/."
    exiting 1
	fi
	if is_true "$VPN_CONF_SWITCH"; then
		mkdir -p "/config/${VPN_TYPE}_extra_confs"
    chown "${PUID}":"${PGID}" "/config/${VPN_TYPE}_extra_confs" &> /dev/null
	fi

  export VPN_CONFIG="$("/etc/qbittorrent/start_find_conf_file.bash" "$VPN_TYPE" "$MOVE_CONFIGS")"
	# Exit if there's no config files found in /config/openvpn or /config/wireguard
	if [[ $? != 0 || -z "${VPN_CONFIG}" ]]; then
    is_true "$MOVE_CONFIGS" && temp_txt=" or /vpn_files/$VPN_TYPE/"
    [ "${VPN_TYPE}" == "openvpn" ] && temp_fext=" or '.ovpn'"
		eprint "$ME: No $VPN_TYPE config file found in /config/$VPN_TYPE/$temp_txt. Make sure the file extension is '.conf'$temp_fext."
    exiting 1
	fi

  iprint "$(print_column VPN_CONFIG "\'${VPN_CONFIG}\'")"

  # If MOVE_CONFIGS is enabled, copy the files into the container
	# Note: The source files are removed
  if is_true "$MOVE_CONFIGS"; then
  # If nothing is moved, it's not a problem since we must already have a
  # value for VPN_CONFIG to be here. This is called every time just in case
  # there is new files that the user has placed into the directory to be used.
    "/etc/qbittorrent/start_move_configs.bash" "$VPN_TYPE" "$VPN_CONF_SWITCH"
  fi

	# convert CRLF (windows) to LF (unix) for ovpn
	dos2unix "${VPN_CONFIG}" > /dev/null

  # TODO: Delete this credentials.conf thing, it's confusing and I've made it obsolete with other options.
	# Read username and password env vars and put them in credentials.conf, then add ovpn config for credentials file
	if ! is_true "$OVPN_NO_CRED_FILE" && [[ "${VPN_TYPE}" == "openvpn" ]]; then
    ! "/etc/qbittorrent/start_write_openvpn_credentials_conf.bash" "$VPN_USERNAME" "$VPN_PASSWORD" "$MOVE_CONFIGS" "$VPN_CONFIG" && exiting 1
	fi

  # NOTE: MOVE_CONFIGS checks end here

  if is_true "$OVPN_NO_CRED_FILE" && [ "${VPN_TYPE}" == "openvpn" ]; then
    # remove all lines starting with "auth-user-pass "
    iprint "Stripping lines beginning with: \"auth-user-pass \""
    sed -i '/^auth-user-pass .*/d' "${VPN_CONFIG}"
  fi

  # Optionally strip non-ipv4 addresses from wg0.conf
  if is_true "$WG_CONF_IPV4_ONLY" && [ "${VPN_TYPE}" == "wireguard" ]; then
    if ! /etc/qbittorrent/start_wireguard_ipv4_only.bash "$VPN_CONFIG" $_wg_conf_ipv4_lines; then
      eprint "$ME: Stripping of non-ipv4 addresses from '$VPN_CONFIG' failed. Words: $_wg_conf_ipv4_lines"
      exiting_switch_extra_confs 1
    fi
  fi

else
	wprint "!!IMPORTANT!! You have set the VPN to disabled, your connection will NOT be secure!"
fi

if [[ "${NAME_SERVERS}" != "0" \
&& $NAME_SERVERS_AFTER == 0 \
|| $NAME_SERVERS_AFTER == 2 ]]; then
	"/etc/qbittorrent/start_add_nameservers.bash" $_name_servers
fi

# The traps up top hold until we exec qbittorrent.bash
if is_true "$VPN_ENABLED"; then
  cd "/$(printf "%s" "$VPN_CONFIG" | cut -d '/' -f 2)/$VPN_TYPE/"
	aprint "Starting ${VPN_TYPE}..."
  "/etc/qbittorrent/start_vpn_start.bash" "$VPN_TYPE" "$VPN_CONFIG" "$VPN_USERNAME" "$VPN_PASSWORD" "$OVPN_NO_CRED_FILE" "$VPN_OPTIONS" &
  wait $!
  "/etc/qbittorrent/start_wait_for_vpn.bash" "$REAPER_WAIT" "$REAPER_PID" &
  wait $!
	"/etc/qbittorrent/iptables.bash" &
  wait $!
  if [[ "${NAME_SERVERS}" != "0" \
	&& $NAME_SERVERS_AFTER == 1 \
	|| $NAME_SERVERS_AFTER == 2 ]]; then
    "/etc/qbittorrent/start_add_nameservers.bash" $_name_servers
  fi
  exec /bin/bash "/etc/qbittorrent/qbittorrent.bash"
else
	wprint "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
  wprint "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
  wprint "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
	wprint "CONTAINER IS RUNNING WITH THE VPN DISABLED."
	wprint "PLEASE MAKE SURE VPN_ENABLED IS SET TO '1'."
	wprint "IF THIS IS INTENTIONAL, YOU CAN IGNORE THIS."
	wprint "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
  wprint "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
  wprint "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
  wprint "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
	exec /bin/bash "/etc/qbittorrent/qbittorrent.bash"
fi
