#!/bin/bash

start_set_and_print_variables() {

  iprint "$(print_column REAPER_WAIT "${REAPER_WAIT}")"

  iprint "$(print_column TZ "\'${TZ}\'")"

  export QBT_TORRENTING_PORT="$(trim "${QBT_TORRENTING_PORT}")"
  if ! is_port "$QBT_TORRENTING_PORT"; then
    export QBT_TORRENTING_PORT=8999
  fi
  iprint "$(print_column QBT_TORRENTING_PORT "${QBT_TORRENTING_PORT}")"

  export QBT_WEBUI_PORT="$(trim "${QBT_WEBUI_PORT}")"
  # if the port is changed within qBittorent itself, the WebUI might be unreachable
  if ! is_port "$QBT_WEBUI_PORT"; then
    export QBT_WEBUI_PORT=8080
  fi
  iprint "$(print_column QBT_WEBUI_PORT "${QBT_WEBUI_PORT}")"

  # If the username is set to anything, leave it alone.
  if [ ! ${!_QBT_USERNAME[@]} ]; then
    export _QBT_USERNAME="$(trim "${_QBT_USERNAME}")"
    if [[ -z "${_QBT_USERNAME}" ]]; then
    # _QBT_USERNAME/PASS might not be correct anymore, but it's better than nothing
      export _QBT_USERNAME="admin"
    fi
  fi
  iprint "$(print_column _QBT_USERNAME "\'${_QBT_USERNAME}\'")"

  # If the password is set to anything, leave it alone.
  if [ ! ${!_QBT_PASSWORD[@]} ]; then
    export _QBT_PASSWORD="$(trim "${_QBT_PASSWORD}")"
    if [[ -z "${_QBT_PASSWORD}" ]]; then
      export _QBT_PASSWORD="adminadmin"
    fi
  fi
  iprint "$(print_column _QBT_PASSWORD "\'${_QBT_PASSWORD}\'")"

  export SHUTDOWN_WAIT="$(trim "${SHUTDOWN_WAIT}")"
  if [[ ! $SHUTDOWN_WAIT =~ ^[0-9]+$ ]]; then
    export  SHUTDOWN_WAIT=180
  fi
  iprint "$(print_column SHUTDOWN_WAIT "${SHUTDOWN_WAIT}")"

  # VPN_DOWN_LOG can be 0, 1, 2 or 3
  export VPN_DOWN_LOG="$(trim "${VPN_DOWN_LOG}")"
  if [[ ! $VPN_DOWN_LOG =~ ^[0123]$ ]]; then
    export  VPN_DOWN_LOG=3
  fi
  iprint "$(print_column VPN_DOWN_LOG "${VPN_DOWN_LOG}")"

  # VPN_DOWN_SCRIPT can be 0, 1 or 2
  export VPN_DOWN_SCRIPT="$(trim "${VPN_DOWN_SCRIPT}")"
  if [[ ! $VPN_DOWN_SCRIPT =~ ^[012]$ ]]; then
    export  VPN_DOWN_SCRIPT=2
  fi
  iprint "$(print_column VPN_DOWN_SCRIPT "${VPN_DOWN_SCRIPT}")"
 
  # Do not trim or modify the VPN username, password or options.
  iprint "$(print_column VPN_USERNAME "\'${VPN_USERNAME}\'")"

  iprint "$(print_column VPN_PASSWORD "\'${VPN_PASSWORD}\'")"

  iprint "$(print_column VPN_OPTIONS "\'${VPN_OPTIONS}\'")"

  export PUID="$(trim "${PUID}")"
  if [[ ! $PUID =~ ^[0-9]+$ ]]; then
    export PUID=1000
  fi
  iprint "$(print_column PUID "${PUID}")"

  export PGID="$(trim "${PGID}")"
  if [[ ! $PGID =~ ^[0-9]+$ ]]; then
    export PGID=1000
  fi
  iprint "$(print_column PGID "${PGID}")"

  export UMASK=$(trim "${UMASK}")
  [[ ! $UMASK =~ ^[0-7][0-7][0-7][0-7]?$ ]] && export UMASK="002"
  iprint "$(print_column UMASK "${UMASK}")"

  export HEALTH_CHECK_AMOUNT=$(trim "${HEALTH_CHECK_AMOUNT}")
  if [[ ! $HEALTH_CHECK_AMOUNT =~ ^[0-9]+$ ]]; then
    export HEALTH_CHECK_AMOUNT=3
  fi

  export HEALTH_CHECK_INTERVAL=$(trim "${HEALTH_CHECK_INTERVAL}")
  if [[ ! $HEALTH_CHECK_INTERVAL =~ ^[0-9]+$ ]]; then
    export HEALTH_CHECK_INTERVAL=29
  fi

  export HEALTH_CHECK_FAILURES=$(trim "${HEALTH_CHECK_FAILURES}")
  if [[ ! $HEALTH_CHECK_FAILURES =~ ^[0-9]+$ ]]; then
    export HEALTH_CHECK_FAILURES=3
  fi

  export HEALTH_CHECK_PING_TIME=$(trim "${HEALTH_CHECK_PING_TIME}")
  if [[ ! $HEALTH_CHECK_PING_TIME =~ ^[0-9]+$ ]]; then
    export HEALTH_CHECK_PING_TIME=14
  fi

  # NAME_SERVERS_AFTER can be 0, 1 or 2
  export NAME_SERVERS_AFTER="$(trim "${NAME_SERVERS_AFTER}")"
  if [[ -z "${NAME_SERVERS_AFTER}" || ! $NAME_SERVERS_AFTER =~ ^[012]$ ]]; then
    export  NAME_SERVERS_AFTER=0
  fi
  iprint "$(print_column NAME_SERVERS_AFTER "${NAME_SERVERS_AFTER}")"

  # https://www.how-to-hide-ip.net/no-logs-dns-server-free-public/
  # FreeDNS: The servers are located in Austria, and you may use the following DNS IPs: 37.235.1.174 and 37.235.1.177.
  # DNS.WATCH: The DNS servers are: 84.200.69.80 (IPv6: 2001:1608:10:25::1c04:b12f) and 84.200.70.40 (IPv6: 2001:1608:10:25::9249:d69b), located in Germany.
  # Note that an array cannot be exported.
  export _name_servers=;
  IFS=',' read -ra _nameservers <<< "${NAME_SERVERS:="37.235.1.174,84.200.69.80,1.1.1.1,84.200.70.40,1.0.0.1,37.235.1.177"}"
  if [ "$_nameservers" != "0" ]; then
    for _name_server in "${_nameservers[@]}"; do
      _name_server="$(trim "$_name_server")"
      is_ip "$_name_server" && _name_servers="$_name_server $_name_servers"
    done
  fi
  _name_servers="$(trim "$_name_servers")"
  iprint "$(print_column NAME_SERVERS "\'"${_name_servers}"\'")"
  
  # Note that an array cannot be exported.
  export _health_check_hosts=;
  IFS=',' read -ra _healthcheckhosts <<< "${HEALTH_CHECK_HOSTS:="1.1.1.1,84.200.69.80"}"
  for _host in "${_healthcheckhosts[@]}"; do
    _host="$(trim "$_host")"
    is_ip "$_host" && _health_check_hosts="$_host $_health_check_hosts"
  done
  _health_check_hosts="$(trim "$_health_check_hosts")"
  # print _hosts at the end

  export _wg_conf_ipv4_lines=;
  IFS=',' read -ra _ipv4_lines <<< "${WG_CONF_IPV4_LINES:="Address,DNS,AllowedIPs,Endpoint"}"
  for _line_to_strip in "${_ipv4_lines[@]}"; do
    _line_to_strip=$(trim "${_line_to_strip}")
    [ ! -z "$_line_to_strip" ] && _wg_conf_ipv4_lines="$_line_to_strip $_wg_conf_ipv4_lines"
  done
  _wg_conf_ipv4_lines="$(trim "$_wg_conf_ipv4_lines")"
  iprint "$(print_column WG_CONF_IPV4_LINES "\'$_wg_conf_ipv4_lines\'")"

  # set_bool variable default; if the env variable is set, it will be tried first
  set_bool MOVE_CONFIGS 0

  set_bool RESTART_CONTAINER 1

  set_bool QBT_SET_INTERFACE 1

  set_bool QBT_UP_SCRIPT 0

  # NOTE: if "/config/${VPN_TYPE}_extra_confs" is empty or non-existent, then the
  # functionally of VPN_CONF_SWITCH does nothing besides print a message.
  set_bool VPN_CONF_SWITCH 1

  set_bool WG_CONF_IPV4_ONLY 1
  
  set_bool VPN_UP_SCRIPT 1
  
  set_bool VPN_ENABLED 1

  set_bool HEALTH_CHECK_SILENT 1

  set_bool OVPN_NO_CRED_FILE 0

  set_bool ENABLE_SSL 0

  set_bool IPTABLE_MANGLE 1

  set_bool LEGACY_IPTABLES 0

  iprint "$(print_column "qbittorrent-nox" "$(/usr/local/bin/qbittorrent-nox -v)")"

  iprint "$(print_column "openssl" "$(openssl version | cut -d '(' -f 1)")"

  iprint "$(print_column "iptables" "$(iptables -V)")"

  iprint "$(print_column "Wireguard" "$(wg -v | cut -d ' ' -f 1,2)")"

  iprint "$(print_column "OpenVPN" "$(openvpn --version | head -n 1 | cut -d '[' -f 1
  )")"
}

if ! (return 0 2>/dev/null); then
  start_set_and_print_variables "$@";
  exit $?;
fi
