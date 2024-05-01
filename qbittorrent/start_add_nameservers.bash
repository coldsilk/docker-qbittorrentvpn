#!/bin/bash

source "/etc/qbittorrent/qbt_utils.bash"

ME="$(basename "$0")"

start_add_nameservers() {
  # $@ = names servers
  # returns 0 if name(s) were added to /etc/resolv.conf, 1 if no none were
  if [[ ! -z "$*" ]]; then
    local ns_check=false;
    local at_least_one=false;
    for name_server_item in $(echo $*); do
      at_least_one=true;
      name_server_item="$(trim "${name_server_item}")"
      if ! cat "/etc/resolv.conf" | grep -q "^nameserver[\ \t]\+$name_server_item[\ \t]*$"; then
        ns_check=true;
        iprint "Adding ${name_server_item} to resolv.conf"
        printf "%s\n" "nameserver ${name_server_item}" >> /etc/resolv.conf
      fi
    done
    $ns_check && return 0;
    if at_least_one && ! ns_check; then
      wprint "Valid nameservers were found but, all were already present in /etc/resolv.conf."
      return 0
    fi
  fi
  eprint "$ME: No nameservers added. Received: $*";
  return 1
}
# determine if the script was sourced or not, sourced == true
if ! (return 0 2>/dev/null); then
  start_add_nameservers "$@";
  exit $?;
fi
