#!/bin/bash

source "/scripts/printers.bash"

qbittorrent_conf_set_interface() {
  # Set the Session\Interface adapter
  if [ "" == "$1" ]; then return 1; fi
  # section [BitTorrent] is require because that is where the to interface options are.
  if cat "$1" | grep -qF '[BitTorrent]'; then
    local adapter="$(netstat -ie | grep -o ".*wg.*: flags=\|.*tun.*: flags=\|.*tap.*: flags=" | cut -d ':' -f 1)"
    if [ "" == "$adapter" ]; then
      eprint "$(basename "$0"): Could not find VPN adapter with command 'netstat -ie'. Cannot set interface in $1"
      return 1
    fi
    if cat "$1" | grep -qF 'Session\Interface='; then
      iprint "Setting line \"Session\\Interface=$adapter\" in $1"
      sed -i "s/^Session\\\Interface=.*/Session\\\Interface=$adapter/" "$1"
    else
      iprint "Adding line \"Session\\Interface=$adapter\" to $1"
      sed -i "s/^\[BitTorrent\]$/[BitTorrent\]\nSession\\\Interface=$adapter/" "$1"
    fi
    if cat "$1" | grep -qF 'Session\InterfaceName='; then
      iprint "Setting line \"Session\\InterfaceName=$adapter\" in $1"
      sed -i "s/^Session\\\InterfaceName=.*/Session\\\InterfaceName=$adapter/" "$1"
    else
      iprint "Adding line \"Session\\InterfaceName=$adapter\" to $1"
      sed -i "s/^\[BitTorrent\]$/[BitTorrent\]\nSession\\\InterfaceName=$adapter/" "$1"
    fi
  else
    eprint "$(basename "$0"): The section [BitTorrent] wasn't found in $1"
    return 1;
  fi
  # I'm not sure if Connection\Interface is still observed
  # https://forum.qbittorrent.org/viewtopic.php?t=4532
  if cat "$1" | grep -qF '[Preferences]'; then
    if cat "$1" | grep -qF 'Connection\Interface='; then
      iprint "Setting line \"Connection\\Interface=$adapter\" in $1"
      sed -i "s/^Connection\\\Interface=.*/Connection\\\Interface=$adapter/" "$1"
    else
      iprint "Adding line \"Connection\\Interface=$adapter\" to $1"
      sed -i "s/^\[Preferences\]$/[Preferences\]\nConnection\\\Interface=$adapter/" "$1"
    fi
    if cat "$1" | grep -qF 'Connection\InterfaceName='; then
      iprint "Setting line \"Connection\\InterfaceName=$adapter\" in $1"
      sed -i "s/^Connection\\\InterfaceName=.*/Connection\\\InterfaceName=$adapter/" "$1"
    else
      iprint "Adding line \"Connection\\InterfaceName=$adapter\" to $1"
      sed -i "s/^\[Preferences\]$/[Preferences\]\nConnection\\\InterfaceName=$adapter/" "$1"
    fi
  else
    eprint "$(basename "$0"): The section [Preferences] wasn't found in $1"
    return 1
  fi
  if cat "$1" | grep -qF "Session\Interface=$adapter" \
  && cat "$1" | grep -qF "Session\InterfaceName=$adapter" \
  && cat "$1" | grep -qF "Connection\Interface=$adapter" \
  && cat "$1" | grep -qF "Connection\InterfaceName=$adapter";
  then return 0; fi
  eprint "$(basename "$0"): sed failed to write interface lines in $1"
  return 1
}

# Determines if the script was sourced or not.
# If ! (return 0 2>/dev/null) evaluates to true, then not sourced.
if ! (return 0 2>/dev/null); then
  qbittorrent_conf_set_interface "$@"
  exit $?;
fi
