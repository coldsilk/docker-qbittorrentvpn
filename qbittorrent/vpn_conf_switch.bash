#!/bin/bash

source "/scripts/printers.bash"

function vpn_conf_switch() (
  # Fill in VPN_TYPE and CONFIG_DIR
  # Create directory "$CONFIG_DIR/openvpn_confs" or "$CONFIG_DIR/wireguard_confs"
  #   then put all of your VPN config files in their respective confs directory.
  # If using openvpn, you must use the filename "default.ovpn"
  #   ie. /config/openvpn/default.opvn
  #   Same principle as when using wireguard that you must use "/config/wireguard/wg0.conf"
  # VPN conf files are rotated based on the oldest modification time.
      VPN_TYPE="${1,,}"
    CONFIG_DIR="$2"
     CONFS_DIR="$CONFIG_DIR/${VPN_TYPE}_confs"
  CONFS_FILTER='ls -tp1 "$CONFS_DIR" | grep -v /' # eval'd
  CONFS_FILTER="ls -tp1r | grep -v / | head -n 1"
            ME="$(basename "$0")"
  echo "$CONFS_DIR::::::::::::::::$2::::::::::::::::::::::::::::::::::::::::::"
  if [ "$VPN_TYPE" != "openvpn" ] && [ "$VPN_TYPE" != "wireguard" ]; then
    eprint "$ME: VPN_TYPE is not \"openvpn\" or \"wireguard\": \"$VPN_TYPE\""
    return 1
  fi

  if [ ! -d "$CONFS_DIR" ]; then
    eprint "$ME: VPN confs directory doesn't exist: \"$CONFS_DIR\""
    return 2
  fi

  # next_vpn_conf is set to the oldest file
  iprint "Finding another VPN conf based on oldest modified time."
  next_vpn_conf="$(ls -tp1r "$CONFS_DIR" | grep -v / | head -n 1)"

  if [ ! -f "$CONFS_DIR/$next_vpn_conf" ]; then
    eprint "$ME: Confs directory seems to have no files: \"$CONFS_DIR\""
    return 3
  fi

  vpn_file="default.ovpn"
  if [ "$VPN_TYPE" == "wireguard" ]; then
    vpn_file="wg0.conf";
  fi
  iprint "Copying VPN file \"$CONFS_DIR/$next_vpn_conf\" to \"$CONFIG_DIR/$VPN_TYPE/$vpn_file\""
  cp -f "$CONFS_DIR/$next_vpn_conf" "$CONFIG_DIR/$VPN_TYPE/$vpn_file"
  touch "$CONFS_DIR/$next_vpn_conf"
  return 0
)
# determine if the script was sourced or not, sourced == true
if ! (return 0 2>/dev/null); then
  vpn_conf_switch "$@";
  exit $?;
fi
