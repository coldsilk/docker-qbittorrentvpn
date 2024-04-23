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
  if [[ $(( 10-($(date +%s)-$START_TIME) )) -gt 0 ]]; then
  	iprint "Exiting in $(( 10-($(date +%s)-$START_TIME) )) seconds."
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

# Make the qBittorrent's config dir.
mkdir -p "$QBT_CONF_DIR"

# Check if qBittorrent.conf exists, if not, copy the template over
if [ ! -e "$QBT_CONF_DIR/qBittorrent.conf" ]; then
	wprint "qBittorrent.conf is missing, this is normal for the first launch! Copying template."
	cp /etc/qbittorrent/qBittorrent.conf "$QBT_CONF_DIR/qBittorrent.conf"
	chmod 755 "$QBT_CONF_DIR/qBittorrent.conf"
	chown ${PUID}:${PGID} "$QBT_CONF_DIR/qBittorrent.conf"
fi

# Checks if SSL is enabled. Or, just remove this SSL option...?
export ENABLE_SSL=$(echo "${ENABLE_SSL}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
source /etc/qbittorrent/ssl_enable.bash

# Create the group "qbittorrent"
groupadd -g $PGID qbittorrent > /dev/null 2>&1

# Create the user "qbittorrent".
useradd -c "qbittorrent user" -g $PGID -u $PUID qbittorrent > /dev/null 2>&1

export UMASK=$(echo "${UMASK}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ -z "${UMASK}" ]]; then export UMASK="002"; fi
# Postpone printing the value until right before starting.

if is_true "$QBT_SET_INTERFACE" \
&& ! /etc/qbittorrent/set_interface.bash "$QBT_CONF_DIR/qBittorrent.conf"; then
  eprint "$ME: QBT_SET_INTERFACE is enabled but the interface was not set properly. Exiting."
  exiting 1
fi

# Set the rights on the /downloads folder
# find /downloads -not -user ${PUID} -execdir chown ${PUID}:${PGID} {} \+
chown ${PUID}:${PGID} /downloads

# Make sure the log directory exists before starting qBittorrent.
mkdir -p /config/qBittorrent/data/logs/

# Make sure that the log file exsits and has the proper rights.
touch /config/qBittorrent/data/logs/qbittorrent.log

# Change ownership of ALL things in /config/qBittorrent.
chown -R ${PUID}:${PGID} /config/qBittorrent

# Start qBittorrent
iprint "Starting qBittorrent daemon..."
su -c "/usr/local/bin/qbittorrent-nox --daemon --profile=/config >> /config/qBittorrent/data/logs/qbittorrent.log 2>&1" qbittorrent

# wait for the qBittorrent to start
wait $!
export qbittorrentpid=$(pidof qbittorrent-nox)

if ! ps -o pid= -p $qbittorrentpid > /dev/null 2>&1; then
  sleep 1
  export qbittorrentpid=$(pidof qbittorrent-nox)
  if ! ps -o pid= -p $qbittorrentpid > /dev/null 2>&1; then
    eprint "$ME: qBittorrent failed to start!"
    exiting 1
  fi
fi

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
  iprint "Attempting to shutdown qBittorrent wit cURL."
  iprint "Sending: curl -v -d \"username=$_QBT_USERNAME&password=$_QBT_PASSWORD\" -X POST localhost:$webui_port/api/v2/auth/login"
  IFS='=;' read -ra sid <<< $(curl -v -d "username=$_QBT_USERNAME&password=$_QBT_PASSWORD" -X POST localhost:$webui_port/api/v2/auth/login 2>&1 | grep "SID");
  iprint "Sending: curl -v -H "Cookie: SID=${sid[1]}" -X POST localhost:$webui_port/api/v2/app/shutdown"
  local curl_print="$(curl -v -H "Cookie: SID=${sid[1]}" -X POST localhost:$webui_port/api/v2/app/shutdown 2>&1)"
  printf "%s\n" "$curl_print"
  if ! printf "%s" "$curl_print" | grep -q "HTTP/1.1 200 OK"; then
    # Try again but, with a different method. _QBT_USERNAME and _QBT_PASSWORD will not matter here.
    # This method is for when "SID" doesn't parse and 1 of the authentication options are enabled.
    eprint "$ME: cURL failed to receive the correct response the 1st time."
    eprint "$ME: Trying a way that requires 1 of the authentication options."
    curl_print="$(curl -v -d "" localhost:$webui_port/api/v2/app/shutdown 2>&1)"  
    printf "%s\n" "$curl_print"
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
    iprint "cURL received \"HTTP/1.1 200 OK\" after sending the shutdown command."
    if is_true "$internal_shutdown"; then
      iprint "Shut down will be clean if time out isn't reached ($SHUTDOWN_WAIT seconds)."
    fi
  fi
  # If the request isn't internal, wait on $qbittorrentpid to exit, then exit.
  if ! is_true "$internal_shutdown"; then
    iprint "Waiting on qBittorrent ($qbittorrentpid) to exit, will say BYE when it does."
    while ps -o pid= -p $qbittorrentpid > /dev/null 2>&1; do
      sleep 1
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

iprint "                UMASK:  $UMASK"

export RESTART_CONTAINER=$(echo "${RESTART_CONTAINER}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ -z "${RESTART_CONTAINER}" || ! $RESTART_CONTAINER =~ ^[01]$ ]]; then
  export RESTART_CONTAINER=1;
fi
iprint "    RESTART_CONTAINER:  ${RESTART_CONTAINER}"

export HEALTH_CHECK_SILENT=$(echo "${HEALTH_CHECK_SILENT}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ -z "${HEALTH_CHECK_SILENT}" || ! $HEALTH_CHECK_SILENT =~ ^[01]$ ]]; then
  export HEALTH_CHECK_SILENT=1
fi
iprint "HEALTH_CHECK_SILENT:    ${HEALTH_CHECK_SILENT}"

export HEALTH_CHECK_AMOUNT=$(echo "${HEALTH_CHECK_AMOUNT}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ -z "${HEALTH_CHECK_AMOUNT}" || ! $HEALTH_CHECK_AMOUNT =~ ^[0-9]+$ ]]; then
  export HEALTH_CHECK_AMOUNT=3
fi
iprint "HEALTH_CHECK_AMOUNT:    ${HEALTH_CHECK_AMOUNT}"

export HEALTH_CHECK_INTERVAL=$(echo "${HEALTH_CHECK_INTERVAL}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ -z "${HEALTH_CHECK_INTERVAL}" || ! $HEALTH_CHECK_INTERVAL =~ ^[0-9]+$ ]]; then
  export HEALTH_CHECK_INTERVAL=29
fi
iprint "HEALTH_CHECK_INTERVAL:  ${HEALTH_CHECK_INTERVAL}"

export HEALTH_CHECK_FAILURES=$(echo "${HEALTH_CHECK_FAILURES}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ -z "${HEALTH_CHECK_FAILURES}" || ! $HEALTH_CHECK_FAILURES =~ ^[0-9]+$ ]]; then
  export HEALTH_CHECK_FAILURES=3
fi
iprint "HEALTH_CHECK_FAILURES:  ${HEALTH_CHECK_FAILURES}"

export HEALTH_CHECK_PING_TIME=$(echo "${HEALTH_CHECK_PING_TIME}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ -z "${HEALTH_CHECK_PING_TIME}" || ! $HEALTH_CHECK_PING_TIME =~ ^[0-9]+$ ]]; then
  export HEALTH_CHECK_PING_TIME=14
fi
iprint "HEALTH_CHECK_PING_TIME: ${HEALTH_CHECK_PING_TIME}"

export HEALTH_CHECK_HOSTS=$(echo "${HEALTH_CHECK_HOSTS}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ -z "${HEALTH_CHECK_HOSTS}" ]]; then
  export HEALTH_CHECK_HOSTS="1.1.1.1, 84.200.69.80"
fi

# split the hosts into an array
IFS=',' read -r -a _temp <<< "$HEALTH_CHECK_HOSTS"
for i in "${_temp[@]}"; do
  temp="$(printf "%s" "$i" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')"
  if [ "$temp" != "" ]; then _hosts+=("$temp"); fi
done

if printf "%s" $HEALTH_CHECK_FAILURES | grep -q "^[0-9]\+$" \
&& printf "%s" $HEALTH_CHECK_PING_TIME | grep -q "^[0-9]\+$" \
&& printf "%s" $HEALTH_CHECK_INTERVAL | grep -q "^[0-9]\+$" \
&& [ ${#_hosts[@]} -gt 0 ];
then
  iprint "       Number of hosts: ${#_hosts[@]}"
  iprint "          Restart time: $(( HEALTH_CHECK_FAILURES * (HEALTH_CHECK_PING_TIME * ${#_hosts[@]} + HEALTH_CHECK_INTERVAL) )) seconds"
fi

iprint "  HEALTH_CHECK_HOSTS: ${_hosts[@]}"

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
  eprint "$ME: No HEALTH_CHECK_HOSTS supplied! Health check routine canceled."
  sleep 2147483647 &
  wait $!
fi

iprint "  Beginning health check."
iprint ""

export failures=0;
export internal_shutdown=0;
while ps -o pid= -p $qbittorrentpid > /dev/null 2>&1; do
  # Ping uses both exit codes 1 and 2. Exit code 2 cannot be used for docker health checks, therefore we use this script to catch error code 2
  # loop through all hosts, if any succeed, set $return_code and break out
  return_code=1
  for i in "${_hosts[@]}"; do
    timeout -k 0 $HEALTH_CHECK_PING_TIME ping -c ${HEALTH_CHECK_AMOUNT} "$i" > /dev/null 2>&1
    rc=$?
    # If "timeout" timed out ping, the exit code will be in the 100's, see timeout --help
    if printf "%s" "$rc" | grep "12[4567]\|137"; then wprint "Ping timed out on $i"; fi
    if [ "0" == "$rc" ]; then
      return_code=0
      break;
    else
      wprint "Failed to ping $i. HC failures: $failures/$HEALTH_CHECK_FAILURES."
    fi
  done
  # If any of the hosts were successful, then there isn't a failure.
  if [[ "${return_code}" -ne 0 ]]; then
    # If all hosts failed, it is considered a single failure.
    failures=$(($failures + 1));
    wprint "$failures/$HEALTH_CHECK_FAILURES HEALTH_CHECK_FAILURES have occurred."
    # Once failures has reached the limit, time to do something.
    if [ "$failures" -eq "$HEALTH_CHECK_FAILURES" ]; then
      if is_true "$VPN_DOWN_SCRIPT" && [ -f "/config/vpn_down.sh" ]; then
        iprint "VPN_DOWN_SCRIPT enabled, sourcing: /config/vpn_down.sh"
        source /config/vpn_down.sh
      fi
      if [[ $VPN_DOWN_FILE == 2 ]] || [[ $VPN_DOWN_FILE == 1 ]] && [ ! -f "/config/vpn_down" ]; then
        iprint "VPN_DOWN_FILE is $VPN_DOWN_FILE, writing to: /config/vpn_down"
        echo "$(date +%s) $(date +"%Y-%m-%d_%H:%M:%S.%4N")" >> "/config/vpn_down"
      fi
      if is_true "$RESTART_CONTAINER"; then
        if is_true "$VPN_CONF_SWITCH" && [ -f "/scripts/vpn_conf_switch.bash" ]; then
          /scripts/vpn_conf_switch.bash "${VPN_TYPE}" "${CONFIG_DIR}"
        fi
        eprint "$ME: Network is seemingly down, restarting container."
        internal_shutdown=1;
        exiting 0
      fi
    fi
  else
    # on every successful check, restart the routine over by setting failures=0
    failures=0;
    if is_true "$VPN_UP_SCRIPT" && [ -f "/config/vpn_up.sh" ]; then
      iprint "VPN_UP_SCRIPT enabled, sourcing: /config/vpn_up.sh"
      source /config/vpn_up.sh
    fi
    if [[ $VPN_DOWN_FILE == 1 ]]; then
      iprint "VPN_DOWN_FILE is $VPN_DOWN_FILE, removing: /config/vpn_down"
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
eprint "If qBittorent has not crashed, you should never see this."
