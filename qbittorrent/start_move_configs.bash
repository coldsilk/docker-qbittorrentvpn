#!/bin/bash

source "/etc/qbittorrent/qbt_utils.bash"

ME="$(basename "$0")"

start_move_configs() {
  # $1 = VPN_TYPE
  # $2 = VPN_CONF_SWITCH
  # returns 0 if anything was moved
  if [ ! -z "$1" ]; then
    local at_least_one=false
		if [ ! -z "$(ls -A "/config/$1/" 2> /dev/null)" ]; then
      at_least_one=true
      iprint "MOVE_CONFIGS is enabled, moving everything in \"/config/$1/\"*"

      rm -rf "/vpn_files/$1"
			mkdir -p "/vpn_files/$1"

			cp -vafT "/config/$1/" "/vpn_files/$1"

      shopt -s dotglob
			rm -vrf "/config/$1/"*
			shopt -u dotglob
		fi
		if is_true "$2" \
		&& [ ! -z "$(ls -A "/config/${1}_extra_confs/" 2> /dev/null)" ]; then
      at_least_one=true
      iprint "MOVE_CONFIGS and VPN_CONF_SWITCH are enabled, moving everything in \"/config/${1}_extra_confs/\"*"

      rm -rf "/vpn_files/${1}_extra_confs"
			mkdir -p "/vpn_files/${1}_extra_confs"

			cp -vafT "/config/${1}_extra_confs/" "/vpn_files/${1}_extra_confs"

			shopt -s dotglob
			rm -vrf "/config/${1}_extra_confs/"*
			shopt -u dotglob
		fi
    $at_least_one && return 0
  fi
  # eprint "$ME: No config files were moved. Received \$1 VPN_TYPE: $1 \$2 VPN_CONF_SWITCH: $2"
  return 1
}
# determine if the script was sourced or not, sourced == true
if ! (return 0 2>/dev/null); then
  start_move_configs "$@";
  exit $?;
fi
