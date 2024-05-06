#!/bin/bash

source "/etc/qbittorrent/qbt_utils.bash"

ME="$(basename "$0")"

exiting() {
  ps -o pid= -p $qbittorrentpid > /dev/null 2>&1 && kill -SIGTERM $$
  if [[ $(date +%s) -lt $(( $START_TIME+$MIN_UPTIME )) ]]; then
  	iprint "Exiting in $(( $MIN_UPTIME-($(date +%s)-$START_TIME) )) seconds."
	else
    iprint "Exiting."
  fi
  # Docker run wants at least 10 seconds between restarts or spamming rules are invoked.
  while [ $(($(date +%s)-$START_TIME)) -lt $MIN_UPTIME ]; do
    sleep 1;
  done
  printf "%s\n" "BYE"
  exit $1
}

# Make the qBittorrent's config and logs directory. eg. where it stores its program files
mkdir -p "/config/qBittorrent/config" "/config/qBittorrent/data/logs/"

# Check if qBittorrent.conf exists, if not, copy the template over
if [ ! -e "/config/qBittorrent/config/qBittorrent.conf" ]; then
	wprint "qBittorrent.conf is missing, this is normal for the first launch! Copying template."
	cp /etc/qbittorrent/qBittorrent.conf "/config/qBittorrent/config/qBittorrent.conf"
	chmod 664 "/config/qBittorrent/config/qBittorrent.conf"
	# chown ${PUID}:${PGID} "/config/qBittorrent/config/qBittorrent.conf"
fi

# Adds SSL configuration to "/config/qBittorrent/config/qBittorrent.conf"
if is_true "$ENABLE_SSL" && ! "/etc/qbittorrent/qbittorrent_enable_ssl.bash" "/config/qBittorrent/config"; then
  exiting 1
fi

# Sets the interface configuration in "/config/qBittorrent/config/qBittorrent.conf"
if is_true "$QBT_SET_INTERFACE" \
&& ! /etc/qbittorrent/qbittorrent_set_interface.bash "/config/qBittorrent/config/qBittorrent.conf"; then
  eprint "$ME: QBT_SET_INTERFACE is enabled but the interface was not set properly."
  exiting 1
fi

# Create the group "qbittorrent"
groupadd -g $PGID qbittorrent > /dev/null 2>&1

# Create the user "qbittorrent".
useradd -c "qbittorrent-nox" -g $PGID -u $PUID qbittorrent > /dev/null 2>&1

chown ${PUID}:${PGID} /downloads

# Make sure that the log file exists.
touch /config/qBittorrent/data/logs/qbittorrent.log

# Before starting, change ownership of all things in /config/qBittorrent.
chown -R ${PUID}:${PGID} /config/qBittorrent

! "/etc/qbittorrent/qbittorrent_start.bash" "qbittorrent" "qbittorrent" "$QBT_WEBUI_PORT" && exiting 1

if [[ -f "/etc/qbittorrent/first_run.txt" ]]; then
  aprint "First run detected. Restarting qbittorrent-nox."
  ! "/etc/qbittorrent/qbittorrent_first_run_stop.bash" "$QBT_WEBUI_PORT" && exiting 1
  ! "/etc/qbittorrent/qbittorrent_start.bash" "qbittorrent" "qbittorrent" "$QBT_WEBUI_PORT" && exiting 1
fi

export qbittorrentpid=$(pidof qbittorrent-nox)
[ -z $qbittorrentpid ] && eprint "$ME: Could not get PID of qbittorrent-nox." && exiting 1

# If we're here, then qbittorrent-nox has started at least once, so delete "first_run.txt".
rm "/etc/qbittorrent/first_run.txt" > /dev/null 2>&1;

if is_true "$QBT_UP_SCRIPT" && [[ -e "/config/qbt_up.sh" ]]; then
  "/config/qbt_up.sh";
fi

iprint ""
iprint "$(print_column "qBittorrent PID" "${qbittorrentpid}")"

# trap for restarts and shutdown
source "/etc/qbittorrent/qbittorrent_trap_shutdown.bash"
# Docker sends SIGTERM by default.
trap qbittorrent_trap_shutdown SIGTERM

iprint "$(print_column HEALTH_CHECK_AMOUNT "${HEALTH_CHECK_AMOUNT}")"

iprint "$(print_column HEALTH_CHECK_INTERVAL "${HEALTH_CHECK_INTERVAL}")"

iprint "$(print_column HEALTH_CHECK_FAILURES "${HEALTH_CHECK_FAILURES}")"

iprint "$(print_column HEALTH_CHECK_PING_TIME "${HEALTH_CHECK_PING_TIME}")"

_health_check_hosts=($_health_check_hosts)
if [ ${#_health_check_hosts[@]} -gt 0 ]; then
  iprint "$(print_column "Number of hosts" "${#_health_check_hosts[@]}")"
  iprint "$(print_column "Maximum restart time" "$(( HEALTH_CHECK_FAILURES * (HEALTH_CHECK_PING_TIME * ${#_health_check_hosts[@]} + HEALTH_CHECK_INTERVAL) + HEALTH_CHECK_INTERVAL )) seconds")"
fi

iprint "$(print_column HEALTH_CHECK_HOSTS "$(trim "${_health_check_hosts[*]}")" )"

iprint ""
export docker_interface=$(netstat -ie | grep -vE "lo|tun|tap|wg" | sed -n '1!p' | grep -P -o -m 1 '^[\w]+')
export docker_ip=$(ifconfig "${docker_interface}" | grep -o "inet [0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+" | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+")
iprint "         Web UI at: $docker_ip:$QBT_WEBUI_PORT"
iprint "  Default Username: admin"

# Determine if there is a temporary password in the log.
if [ -e "/config/qBittorrent/data/logs/qbittorrent.log" ]; then
  line_num="$(tail -n 100 "/config/qBittorrent/data/logs/qbittorrent.log" | grep -no "[*]\+[\ \t]*Information[\ \t]*[*]\+$" | cut -d ':' -f 1 | tail -n 1)"
  temp_password="$(tail -n $(( 101 - line_num )) "/config/qBittorrent/data/logs/qbittorrent.log" | grep -o "temporary password is provided for this session:[\ \t]*.*$" | sed "s/temporary password is provided for this session:[\ \t]*//" | tail -n 1)"
fi
if [ -z "$temp_password" ];then
  iprint "  Default Password: adminadmin"
else
  iprint "Temporary Password: $temp_password"
fi
iprint ""

if ! is_true "$RESTART_CONTAINER"; then
  wprint "RESTART_CONTAINER is set to $RESTART_CONTAINER. Health check routine canceled."
  sleep 2147483647 &
  wait $!
fi

if [ ! ${#_health_check_hosts[@]} -gt 0 ]; then
  eprint "$ME: No valid HEALTH_CHECK_HOSTS supplied! Health check routine canceled."
  env
  sleep 2147483647 &
  wait $!
fi

iprint "  Beginning health check."
iprint ""

export failures=0;
export internal_shutdown=0;
source "/etc/qbittorrent/health_check_success_directives.bash"
source "/etc/qbittorrent/health_check_failure_directives.bash"
while ps -o pid= -p $qbittorrentpid > /dev/null 2>&1; do
  # Ping uses both exit codes 1 and 2. Exit code 2 cannot be used for docker health checks, therefore we use this script to catch error code 2
  # loop through all hosts, if any succeed, set $success and break out
  success=false
  if "/etc/qbittorrent/health_check_for_loop_on_hosts.bash" \
    "$HEALTH_CHECK_PING_TIME" \
    "$HEALTH_CHECK_AMOUNT" \
    "$failures" \
    "$HEALTH_CHECK_FAILURES" \
    "${_health_check_hosts[@]}";
  then
    success=true;
  fi
   # If any of the hosts were successful, then there isn't a failure.
  if is_true $success; then
    # on every successful check, restart the routine over by setting failures=0
    failures=0;
    health_check_vpn_up_script "$VPN_UP_SCRIPT"
    health_check_vpn_down_log_rm "$VPN_DOWN_LOG"
  else
    # If all hosts failed, it is considered a single failure.
    failures=$(($failures + 1));
    wprint "$failures/$HEALTH_CHECK_FAILURES HEALTH_CHECK_FAILURES have occurred."
    # Once failures has reached the limit, time to do something.
    if [ "$failures" -eq "$HEALTH_CHECK_FAILURES" ]; then
      health_check_vpn_down_script "$VPN_DOWN_SCRIPT"
      health_check_vpn_down_log "$VPN_DOWN_LOG"
      health_check_vpn_conf_switch "$VPN_TYPE" "$VPN_CONFIG" "$VPN_CONF_SWITCH" "$RESTART_CONTAINER"
      if is_true "$RESTART_CONTAINER"; then
        eprint "$ME: The internet is seemingly down, restarting."
        internal_shutdown=1;
        exiting 0
      fi
    fi
  fi
  ! is_true "$HEALTH_CHECK_SILENT" && iprint "Network is up."
  # use wait to allow the trap to trigger
  sleep $HEALTH_CHECK_INTERVAL & export HEALTH_CHECK_SLEEP_PID=$!
  wait $HEALTH_CHECK_SLEEP_PID
done
eprint "$ME: It seems that qBittorrent is not running."
exiting 1
