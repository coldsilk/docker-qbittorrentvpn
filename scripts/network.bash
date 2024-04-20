#!/bin/bash

util_is_ipv4_private() {
  # To match the below private addresses.
  # $* : 3 forms supported.
  #       "172.16.34.55/32"
  #    or "172.16.34.55"
  #    or "172.16.34.55:45634"
  # 10.0.0.0/8 IP addresses: 10.0.0.0 – 10.255.255.255
  # 172.16.0.0/12 IP addresses: 172.16.0.0 – 172.31.255.255
  # 192.168.0.0/16 IP addresses: 192.168.0.0 – 192.168.255.255
  # $* : ie. "172.16.34.55/32" or no mask ie. "172.16.34.55"
  if [ "$*" == "" ]; then return 1; fi
  if [ "$(echo "$*" | grep "^192\.168\.\(25[0-5]\|2[0-4][0-9]\|[01]\?[0-9][0-9]\?\)\.\(25[0-5]\|2[0-4][0-9]\|[01]\?[0-9][0-9]\?\)\(/[0-9]\|/[12][0-9]\|/3[012]\)\?\(:[0-5]\?[0-9]\{0,4\}$\|:6[0-5][0-5][0-3][0-5]$\)\?$")" ] \
  || [ "$(echo "$*" | grep "^10\.\(25[0-5]\|2[0-4][0-9]\|[01]\?[0-9][0-9]\?\)\.\(25[0-5]\|2[0-4][0-9]\|[01]\?[0-9][0-9]\?\)\.\(25[0-5]\|2[0-4][0-9]\|[01]\?[0-9][0-9]\?\)\(/[0-9]\|/[12][0-9]\|/3[012]\)\?\(:[0-5]\?[0-9]\{0,4\}$\|:6[0-5][0-5][0-3][0-5]$\)\?$")" ] \
  || [ "$(echo "$*" | grep "^172\.\(1[6789]\|2[0-9]\|3[01]\)\.\(25[0-5]\|2[0-4][0-9]\|[01]\?[0-9][0-9]\?\)\.\(25[0-5]\|2[0-4][0-9]\|[01]\?[0-9][0-9]\?\)\(/[0-9]\|/[12][0-9]\|/3[012]\)\?\(:[0-5]\?[0-9]\{0,4\}$\|:6[0-5][0-5][0-3][0-5]$\)\?$")" ];
  then return 0; fi
  return 1
}

util_is_ipv4() {
  # $* : 3 forms supported.
  #       "172.16.34.55/32"
  #    or "172.16.34.55"
  #    or "172.16.34.55:45634"
  # local _0_255="\(25[0-5]\|2[0-4][0-9]\|[01]\?[0-9][0-9]\?\)" # range: [0, 255]
  # local _mask="\([0-9]\|[12][0-9]\|3[012]\)" # range: [0, 32]
  # local _port="\(:[0-5]\?[0-9]\{0,4\}$\|:6[0-5][0-5][0-3][0-5]$\)" # range: [0, 65535]
  if [ "$*" == "" ]; then return 1; fi
  if [ "$(echo "$*" | grep "^\(25[0-5]\|2[0-4][0-9]\|[01]\?[0-9][0-9]\?\)\.\(25[0-5]\|2[0-4][0-9]\|[01]\?[0-9][0-9]\?\)\.\(25[0-5]\|2[0-4][0-9]\|[01]\?[0-9][0-9]\?\)\.\(25[0-5]\|2[0-4][0-9]\|[01]\?[0-9][0-9]\?\)\(/[0-9]\|/[12][0-9]\|/3[012]\)\?\(:[0-5]\?[0-9]\{0,4\}$\|:6[0-5][0-5][0-3][0-5]$\)\?$")" ];
  then return 0; fi
  return 1
}

wireguard_is_connected() {
  printf "%s" "$(wg show | grep -F "latest handshake: ")" | \
    grep -q "\(: 1 minute\|: \([1-5][0-9]\|[1-9]\) second\|: 2 minutes ago\|: 2 minutes, 1 second\|: Now\)";
  return $?
}
