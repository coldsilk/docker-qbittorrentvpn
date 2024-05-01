#!/bin/bash

source "/etc/qbittorrent/qbt_utils.bash"

ME="$(basename "$0")"

qbittorrent_set_interface() {
  # Set the Session\Interface adapter
  # $1 = File to edit, eg. "/config/qBittorrent/config/qBittorrent.conf"
  # returns 0 on successful editing, 1 on failures
  [ ! -e "$1" ] && eprint "Cannot edit for interfacce. File does not seem to exist: \"$1\"" && return 1
  # section [BitTorrent] is required because that is where the interface options are.
  if cat "$1" | grep -q '^\[BitTorrent\]$'; then
    local adapter="$(netstat -ie | grep -o ".*wg.*: flags=\|.*tun.*: flags=\|.*tap.*: flags=" | cut -d ':' -f 1)"
    if [ "" == "$adapter" ]; then
      eprint "$ME: Could not find VPN adapter with command 'netstat -ie'. Cannot set interface in $1"
      return 1
    fi
    if cat "$1" | grep -qF 'Session\Interface='; then
      iprint "Setting \"Session\\Interface=$adapter\" in $1"
      sed -i "s/^Session\\\Interface=.*/Session\\\Interface=$adapter/g" "$1"
    else
      iprint "Adding \"Session\\Interface=$adapter\" to $1"
      sed -i "s/^\[BitTorrent\]$/[BitTorrent\]\nSession\\\Interface=$adapter/" "$1"
    fi
    if cat "$1" | grep -qF 'Session\InterfaceName='; then
      iprint "Setting \"Session\\InterfaceName=$adapter\" in $1"
      sed -i "s/^Session\\\InterfaceName=.*/Session\\\InterfaceName=$adapter/g" "$1"
    else
      iprint "Adding \"Session\\InterfaceName=$adapter\" to $1"
      sed -i "s/^\[BitTorrent\]$/[BitTorrent\]\nSession\\\InterfaceName=$adapter/" "$1"
    fi
  else
    eprint "$ME: The section [BitTorrent] was not found in $1"
    return 1;
  fi
  # I'm not sure if Connection\Interface is still observed
  # https://forum.qbittorrent.org/viewtopic.php?t=4532
  if cat "$1" | grep -q '^\[Preferences\]$'; then
    if cat "$1" | grep -qF 'Connection\Interface='; then
      iprint "Setting \"Connection\\Interface=$adapter\" in $1"
      sed -i "s/^Connection\\\Interface=.*/Connection\\\Interface=$adapter/g" "$1"
    else
      iprint "Adding \"Connection\\Interface=$adapter\" to $1"
      sed -i "s/^\[Preferences\]$/[Preferences\]\nConnection\\\Interface=$adapter/" "$1"
    fi
    if cat "$1" | grep -qF 'Connection\InterfaceName='; then
      iprint "Setting \"Connection\\InterfaceName=$adapter\" in $1"
      sed -i "s/^Connection\\\InterfaceName=.*/Connection\\\InterfaceName=$adapter/g" "$1"
    else
      iprint "Adding \"Connection\\InterfaceName=$adapter\" to $1"
      sed -i "s/^\[Preferences\]$/[Preferences\]\nConnection\\\InterfaceName=$adapter/" "$1"
    fi
  else
    eprint "$ME: The section [Preferences] was not found in $1"
    return 1
  fi
  if cat "$1" | grep -qF "Session\Interface=$adapter" \
  && cat "$1" | grep -qF "Session\InterfaceName=$adapter" \
  && cat "$1" | grep -qF "Connection\Interface=$adapter" \
  && cat "$1" | grep -qF "Connection\InterfaceName=$adapter";
  then return 0; fi
  eprint "$ME: sed failed to write interface lines in $1"
  return 1
}

# Determines if the script was sourced or not.
# If ! (return 0 2>/dev/null) evaluates to true, then not sourced.
if ! (return 0 2>/dev/null); then
  qbittorrent_set_interface "$@"
  exit $?;
fi
