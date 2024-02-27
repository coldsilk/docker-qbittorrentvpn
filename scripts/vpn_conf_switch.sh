#!/bin/bash
function vpn_conf_switch() (
  # Fill in VPN_TYPE and CONFIG_DIR
  # Create directory "$CONFIG_DIR/openvpn_confs" or "$CONFIG_DIR/wireguard_confs"
  #   then put all of your VPN config files in their respective confs directory.
  # If using openvpn, you must use the filename "default.ovpn"
  #   ie. /config/openvpn/default.opvn
  #   Same principle as when using wireguard that you must use "/config/wireguard/wg0.conf"
  # VPN conf files are rotated based on the oldest modification time.
      VPN_TYPE="${1,,}"
    CONFIG_DIR="/config"
     CONFS_DIR="$CONFIG_DIR/${VPN_TYPE}_confs"
  CONFS_FILTER='ls -tp1 "$CONFS_DIR" | grep -v /' # eval'd
            ME=$(basename "$0")

  if [ ! -d "$CONFS_DIR" ]; then
    echo "[ERROR] $ME: VPN confs directory doesn't exist: \"$CONFS_DIR\"" | ts '%Y-%m-%d %H:%M:%.S'
    return 1
  fi

  if [ "$VPN_TYPE" != "openvpn" ] && [ "$VPN_TYPE" != "wireguard" ]; then
    echo "[ERROR] $ME: VPN_TYPE is not \"openvpn\" or \"wireguard\": \"$VPN_TYPE\"" | ts '%Y-%m-%d %H:%M:%.S'
    return 2
  fi

  next_vpn_conf=""
  # next_vpn_conf is set to the last line of the output
  while IFS= read line ; do
      next_vpn_conf=$line;
  done < <(eval "$CONFS_FILTER");

  if [ ! -f "$CONFS_DIR/$next_vpn_conf" ]; then
    echo "[ERROR] $ME: confs directory seems to have no files: \"$CONFS_DIR\"" | ts '%Y-%m-%d %H:%M:%.S'
    return 3
  fi

  vpn_file="default.ovpn"
  if [ "$VPN_TYPE" == "wireguard" ]; then
    vpn_file="wg0.conf";
  fi
  echo "[INFO] $ME: copying VPN file \"$CONFS_DIR/$next_vpn_conf\" to \"$CONFIG_DIR/$VPN_TYPE/$vpn_file\"" | ts '%Y-%m-%d %H:%M:%.S'
  cp -f "$CONFS_DIR/$next_vpn_conf" "$CONFIG_DIR/$VPN_TYPE/$vpn_file"
  touch "$CONFS_DIR/$next_vpn_conf"
  return 0
)
# determine if the script was sourced or not, sourced == true
if ! (return 0 2>/dev/null); then
  vpn_conf_switch "$@";
  exit $?;
fi
