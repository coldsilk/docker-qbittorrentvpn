#!/bin/bash

source "/scripts/printers.bash"

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

exiting() {
  if ps -o pid= -p $qbittorrentpid > /dev/null 2>&1; then
    kill -6 $$ # 6 == SIGABRT
  fi
  # docker wants at least 10 seconds between restarts or spamming rules invoke
  while [ $(($(date +%s)-$START_TIME)) -lt 11 ]; do
    sleep 1;
  done
  printf "%s\n" "BYE"
  exit $1
}

# qBittorrent's config dir, eg. where it stores its runtime files
export QBT_CONF_DIR="/config/qBittorrent/config"

# Check if /config/qBittorrent exists, if not make the directory
if [[ ! -e "$QBT_CONF_DIR" ]]; then
	mkdir -p "$QBT_CONF_DIR"
fi
# Set the correct rights accordingly to the PUID and PGID on /config/qBittorrent
chown -R ${PUID}:${PGID} /config/qBittorrent

# TODO: this needs to be reworked/rethought, shouldn't chown _ANY_ existing directories
# Set the rights on the /downloads folder
find /downloads -not -user ${PUID} -execdir chown ${PUID}:${PGID} {} \+

# Check if qBittorrent.conf exists, if not, copy the template over
if [ ! -e "$QBT_CONF_DIR/qBittorrent.conf" ]; then
	wprint "qBittorrent.conf is missing, this is normal for the first launch! Copying template."
	cp /etc/qbittorrent/qBittorrent.conf "$QBT_CONF_DIR/qBittorrent.conf"
	chmod 755 "$QBT_CONF_DIR/qBittorrent.conf"
	chown ${PUID}:${PGID} "$QBT_CONF_DIR/qBittorrent.conf"
fi

# Checks if SSL is enabled. Or, just remove this SSL option...?
export ENABLE_SSL=$(echo "${ENABLE_SSL,,}")
source /etc/qbittorrent/ssl_enable.bash

# Check if the PGID exists, if not create the group with the name 'qbittorrent'
grep $"${PGID}:" /etc/group > /dev/null 2>&1
if [ $? -eq 0 ]; then
	iprint "A group with PGID $PGID already exists in /etc/group within this container, nothing to do."
else
	iprint "A group with PGID $PGID does not exist within this container, adding a group called 'qbittorrent' with PGID $PGID"
	groupadd -g $PGID qbittorrent
fi

# Check if the PUID exists, if not create the user with the name 'qbittorrent', with the correct group
id ${PUID} > /dev/null 2>&1
if [ $? -eq 0 ]; then
	iprint "An user with PUID $PUID already exists within this container, nothing to do."
else
	iprint "An user with PUID $PUID does not exist within this container, adding an user called 'qbittorrent user' with PUID $PUID"
	useradd -c "qbittorrent user" -g $PGID -u $PUID qbittorrent
fi

# Set the umask
if [[ ! -z "${UMASK}" ]]; then
	iprint "UMASK defined as '${UMASK}'"
	export UMASK=$(echo "${UMASK}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
else
	wprint "UMASK not defined (via -e UMASK), defaulting to '002'"
	export UMASK="002"
fi

if is_true "$QBT_SET_INTERFACE" \
&& ! /etc/qbittorrent/set_interface.bash "$QBT_CONF_DIR/qBittorrent.conf"; then
  eprint "$ME: QBT_SET_INTERFACE is enabled but the interface was not set properly. Exiting."
  exiting 1
fi

# Start qBittorrent
iprint "Starting qBittorrent daemon..."
/usr/local/bin/qbittorrent-nox --daemon --profile=/config >> /config/qBittorrent/data/logs/qbittorrent.log 2>&1 &

# wait for the qBittorrent to start
wait $!
export qbittorrentpid=$(pidof qbittorrent-nox)

if ! ps -o pid= -p $qbittorrentpid > /dev/null 2>&1; then
  eprint "$ME: qBittorrent failed to start!"
  exiting 1
fi

chmod -R 755 /config/qBittorrent

iprint "      qBittorrent PID:  $qbittorrentpid"

# trap for restarts and shutdown
handle_shutdown() {
  iprint "Received SIGTERM, SIGABRT or SIGINT. Stopping container..."
  local webui_port="$(cat "$QBT_CONF_DIR/qBittorrent.conf" | grep '^[\t ]*WebUI\\Port[\t ]*' | sed 's~^[\t ]*WebUI\\Port=[\t=\ ]*~~')"
  if [ "$webui_port" == "" ]; then webui_port=$QBT_WEBUI_PORT; fi
  if [ "$webui_port" == "" ]; then webui_port=8080; fi
  # For this curl command to work, you must enable the option
  # "Bypass authentication for clients on localhost"
  # or "Bypass authentication for clients in whitelisted IP subnets"
  # or set _QBT_USERNAME and _QBT_PASSWORD
  # As of qBittorrent v4.6.4, the 2 authentication options are under the "Web UI" tab.
  iprint "Sending: curl -v -d \"username=$_QBT_USERNAME&password=$_QBT_PASSWORD\" -X POST 127.0.0.1:$webui_port/api/v2/auth/login"
  IFS='=;' read -ra sid <<< $(curl -v -d "username=$_QBT_USERNAME&password=$_QBT_PASSWORD" -X POST 127.0.0.1:$webui_port/api/v2/auth/login 2>&1 | grep "SID");
  iprint "Sending: curl -v -H "Cookie: SID=${sid[1]}" -X POST 127.0.0.1:$webui_port/api/v2/app/shutdown"
  local curl_print="$(curl -v -H "Cookie: SID=${sid[1]}" -X POST 127.0.0.1:$webui_port/api/v2/app/shutdown 2>&1)"
  printf "%s" "$curl_print"
  if ! printf "%s" "$curl_print" | grep -q "HTTP/1.1 200 OK"; then
    # Try again but, with a different method. _QBT_USERNAME and _QBT_PASSWORD will not matter here.
    # This method is for when "SID" doesn't parse and 1 of the authentication options are enabled.
    eprint "$ME: cURL failed to receive the correct response the 1st time."
    eprint "$ME: Trying a way that requires 1 of the authentication options."
    curl_print="$(curl -v -d "" 127.0.0.1:$webui_port/api/v2/app/shutdown 2>&1)"  
    printf "%s" "$curl_print"
  fi
  # If "HTTP/1.1 200 OK" was NOT received, send SIGABRT
  if ! printf "%s" "$curl_print" | grep -q "HTTP/1.1 200 OK"; then
    wprint "cURL request to shutdown failed, sending SIGABRT to qBittorrent pid: $qbittorrentpid"
    wprint "NOTE: cURL requires: \"Bypass authentication for clients on localhost\""
    wprint "     or \"Bypass authentication for clients in whitelisted IP subnets\""
    wprint "     or setting _QBT_USERNAME and _QBT_PASSWORD."
    wprint "     The 2 authentication options are in qBittorrent under the "Web UI" tab"
    kill -6 $qbittorrentpid &
  else
    iprint ""
    iprint "cURL received \"HTTP/1.1 200 OK\" after sending the shutdown command."
    iprint "qBittorrent should shut down cleanly."
  fi
  # If the request isn't internal, wait on $qbittorrentpid to exit, then exit.
  if ! is_true "$internal_shutdown"; then
    iprint "Waiting on qBittorrent ($qbittorrentpid) to exit, will say BYE when it does."
    while ps -o pid= -p $qbittorrentpid > /dev/null 2>&1; do
      sleep 1;
    done
    exiting 0
  fi
  local now=$(date +%s)
  while ps -o pid= -p $qbittorrentpid > /dev/null 2>&1; do
    iprint "Waiting on the qBittorrent process to exit. PID: $qbittorrentpid"
    sleep 1
    if [ $(($(date +%s)-$now)) -gt $SHUTDOWN_WAIT ]; then
      kill -9 $qbittorrentpid
      eprint "$ME: The qBittorrent process was still running at exit."
      exiting 99;
    fi
  done
  exiting 0
}
trap handle_shutdown SIGTERM SIGABRT SIGINT

# Make sure that the log file has the proper rights
if [[ -e /config/qBittorrent/data/logs/qbittorrent.log ]]; then
  chmod 775 /config/qBittorrent/data/logs/qbittorrent.log
fi

if [ -z ${RESTART_CONTAINER} ]; then
  export RESTART_CONTAINER=1;
fi
iprint "    RESTART_CONTAINER:  ${RESTART_CONTAINER}"

if [[ -z "${HEALTH_CHECK_SILENT}" ]]; then
  export HEALTH_CHECK_SILENT=1
fi
iprint "HEALTH_CHECK_SILENT:    ${HEALTH_CHECK_SILENT}"

if [[ -z ${HEALTH_CHECK_AMOUNT} ]]; then
  export HEALTH_CHECK_AMOUNT=3
fi
iprint "HEALTH_CHECK_AMOUNT:    ${HEALTH_CHECK_AMOUNT}"

if [[ -z "${HEALTH_CHECK_INTERVAL}" ]]; then
  export HEALTH_CHECK_INTERVAL=30
fi
iprint "HEALTH_CHECK_INTERVAL:  ${HEALTH_CHECK_INTERVAL}"

if [[ -z "${HEALTH_CHECK_FAILURES}" ]]; then
  export HEALTH_CHECK_FAILURES=3
fi
iprint "HEALTH_CHECK_FAILURES:  ${HEALTH_CHECK_FAILURES}"

if [[ -z "${HEALTH_CHECK_PING_TIME}" ]]; then
  export HEALTH_CHECK_PING_TIME=15
fi
iprint "HEALTH_CHECK_PING_TIME: ${HEALTH_CHECK_PING_TIME}"

if [[ -z "${HEALTH_CHECK_HOST}" ]]; then
  export HEALTH_CHECK_HOST="1.1.1.1,84.200.69.80"
fi

# split the hosts into an array
IFS=',' read -r -a _temp <<< "$HEALTH_CHECK_HOST"
for i in "${_temp[@]}"; do
  if [ "$i" != "" ]; then _hosts+=("$i"); fi
done

if printf "%s" $HEALTH_CHECK_FAILURES | grep -q "^[0-9]\+$" \
&& printf "%s" $HEALTH_CHECK_FAILURES | grep -q "^[0-9]\+$" \
&& printf "%s" $HEALTH_CHECK_FAILURES | grep -q "^[0-9]\+$" \
&& [ ${#_hosts[@]} -gt 0 ];
then
  iprint "       Number of hosts: ${#_hosts[@]}"
  iprint "          Restart time: $(( HEALTH_CHECK_FAILURES * (HEALTH_CHECK_PING_TIME * ${#_hosts[@]} + HEALTH_CHECK_INTERVAL) )) seconds"
fi

iprint "HEALTH_CHECK_HOST(s): ${HEALTH_CHECK_HOST}"

iprint ""
export LAN_IP="$(ip a | grep -o "^[ \t]*inet[ \t]*172\.\(1[6789]\|2[0-9]\|30\|31\)\.\(25[0-5]\|2[0-4][0-9]\|[01]\?[0-9][0-9]\?\).\(25[0-5]\|2[0-4][0-9]\|[01]\?[0-9][0-9]\?\)" | sed 's/[ \t]*inet[ \t]*//')"
if [ ! "$LAN_IP" ]; then LAN_IP="localhost"; fi
iprint "         Web UI at: $LAN_IP:$QBT_WEBUI_PORT"
iprint "  Default Username: admin"
iprint "  Default Password: adminadmin"
iprint ""

if [ "$RESTART_CONTAINER" == "0" ]; then
  wprint "RESTART_CONTAINER is set to 0. Health check routine canceled."
  sleep 2147483647 &
  wait $!
fi

if [ "0" == "${#_hosts[@]}" ]; then
  eprint "$ME: No Health Check Hosts supplied! Health check routine canceled."
  sleep 2147483647 &
  wait $!
fi

iprint "  Beginning health check."
iprint ""

export failures=0;
while true; do
  # Ping uses both exit codes 1 and 2. Exit code 2 cannot be used for docker health checks, therefore we use this script to catch error code 2
  # loop through all hosts, if any succeed, set $return_code and break out
  return_code=1
  for i in "${_hosts[@]}"; do
    timeout -k 0 $HEALTH_CHECK_PING_TIME ping -c ${HEALTH_CHECK_AMOUNT} "$i" > /dev/null 2>&1
    rc=$?
    if printf "%s" "$rc" | grep "12[4567]\|137"; then wprint "Ping timed out on $i"; fi
    if [ "0" == "$rc" ]; then
      return_code=0
      break;
    else
      wprint "Failed to ping $i. Internet failures is $failures of $HEALTH_CHECK_FAILURES."
    fi
  done
  # if any of the hosts were successful, then there isn't a failure
  if [[ "${return_code}" -ne 0 ]]; then
    # if all hosts failed, it is considered a failure
    failures=$(($failures + 1));
    wprint "$failures of $HEALTH_CHECK_FAILURES internet failures have occurred."
    if [ "$failures" -eq "$HEALTH_CHECK_FAILURES" ]; then
      if is_true "$VPN_DOWN_SCRIPT" && [ -f "/config/vpn_down.sh" ]; then
        source /config/vpn_down.sh
      fi
      if is_true "$VPN_DOWN_FILE" || [[ $VPN_DOWN_FILE == 2 ]] && [ ! -f "/config/vpn_down" ]; then
        echo "$(date +%s) $(date +"%Y-%m-%d_%H:%M:%S.%4N")" >> "/config/vpn_down"
      fi
      if is_true "$RESTART_CONTAINER"; then
        if is_true "$VPN_CONF_SWITCH" && [ -f "/scripts/vpn_conf_switch.bash" ]; then
          /scripts/vpn_conf_switch.bash "${VPN_TYPE}" "${CONFIG_DIR}"
        fi
        eprint "$ME: Network is seemingly down, restarting container."
        export internal_shutdown=1;
        exiting 0
      fi
    fi
  else
    failures=0;
    if is_true "$VPN_UP_SCRIPT" && [ -f "/config/vpn_up.sh" ]; then
      source /config/vpn_up.sh
    fi
    if is_true "$VPN_DOWN_FILE"; then
      \rm -f "/config/vpn_down" > /dev/null 2>&1
    fi
  fi
  if ! is_true "$HEALTH_CHECK_SILENT"; then
    iprint "Network is up."
  fi
  # use wait to allow the trap to trigger
  sleep ${HEALTH_CHECK_INTERVAL} &
  wait $!
done
