#!/bin/bash

print_prefix() {
  printf "%s" "$(date +"%Y-%m-%d_%H:%M:%S.%4N"):"
}

vprint() {
  printf "%s\n" "$(print_prefix) $*";
}

iprint() {
  printf "%s\n" "$(print_prefix) [_info]: $*";
}

eprint() {
  >&2 printf "%s\n" "$(print_prefix) [ERROR]: $*";
}

wprint() {
  printf "%s\n" "$(print_prefix) [_warn]: $*";
}

aprint() {
  printf "%s\n" "$(print_prefix) [~~~~~]: $*";
}

hprint() {
  printf "%s\n" "$(print_prefix) [hello]: $*";
}

print_column() {
  # Print the name with leading spaces,
  printf "%23s" "$1:"
  # then print the value.
  printf " $2"
}

is_true() {
  if [[ ! -z "$1" \
  && "${1}" == "1" \
  || "${1,,}" == "true" \
  || "${1,,}" == "yes" \
  || "${1,,}" == "on" ]];
  then return 0; fi
  return 1;
}

trim() {
  if [[ ! -z "$1" ]]; then
	  printf "%s" "$1" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~'
    return $?
  fi
  return 1
}

set_bool() {
	# $1 variable name, $2 default value
	export $1=$(printf "%s" "${!1}" | grep -o "[01]" | head -n 1)
	if [ -z "${!1}" ]; then export $1=$2; fi
  iprint "$(print_column $1 ${!1})"
}

is_ipv4() {
  # $* : 4 forms supported.
  #       "172.16.34.55/32"
  #    or "172.16.34.55"
  #    or "172.16.34.55:45634"
  #    or "0/32"
  # Uses the below 3 regexes.
  # local _0_255="\(25[0-5]\|2[0-4][0-9]\|[01]\?[0-9][0-9]\?\)" # range: [0, 255]
  # local _mask="\(/[12][0-9]\|/3[210]\|/[0-9]$\)" # range: [0, 32]
  # local _port="\(:[0-5]\?[0-9]\{0,4\}$\|:6[0-5][0-5][0-3][0-5]$\)" # range: [0, 65535]
  # Expression: ^(_0_255).(_0_255).(_0_255).(_0_255)(_mask|_port)?$
  if [ ! -z "$*" ]; then
    # if printf "%s" "$*" | grep -q "^$_0_255\.$_0_255\.$_0_255\.$_0_255\($_mask\|$_port\)\?$";
    if printf "%s" "$*" | grep -q "^\(25[0-5]\|2[0-4][0-9]\|[01]\?[0-9][0-9]\?\)\.\(25[0-5]\|2[0-4][0-9]\|[01]\?[0-9][0-9]\?\)\.\(25[0-5]\|2[0-4][0-9]\|[01]\?[0-9][0-9]\?\)\.\(25[0-5]\|2[0-4][0-9]\|[01]\?[0-9][0-9]\?\)\(\(/[12][0-9]\|/3[210]\|/[0-9]$\)\|\(:[0-5]\?[0-9]\{0,4\}$\|:6[0-5][0-5][0-3][0-5]$\)\)\?$";
    then
    return 0; fi
    printf "%s" "$*" | grep -q "^0\(/[12][0-9]\|/3[210]\|/[0-9]$\)" && return 0
  fi
  return 1
}

is_ipv6() {
  if [[ ! -z "$*" ]]; then
    ipcalc -cs6 "$*" && return 0
  fi
  return 1;
}

is_ip() {
  if [[ ! -z "$*" ]]; then
    is_ipv4 "$*" && return 0
    is_ipv6 "$*" && return 0
  fi
  return 1;
}

is_port() {
  printf "%s" "$*" | grep -q "^[0-5]\?[0-9]\{0,4\}$\|^6[0-5][0-5][0-3][0-5]$" && return 0
  return 1
}

reaper_spawn() {
  # $1 = maximum time limit to wait
  # $2 = signal for kill to send
  # $3 = PID to kill after limit is reached
  # returns 0 on successful spawn, 1 on failure
  # prints the PID of the sleep process in the child shell
  [ ! -z "$1" ] && [ ! -z "$2" ] && [ ! -z "$3" ] || return 1
  ( sleep $1 && kill -$2 $3 ) > /dev/null &
  local child_pid=$!
  local now=$(date +%s)
  local sleep_pid=$(ps -o pid= --ppid $child_pid)
  while [ -z $sleep_pid ] && [ $(($(date +%s)-$now)) -lt 4 ]; do
    sleep_pid=$(ps -o pid= --ppid $child_pid)
  done
  echo $sleep_pid
  [[ $sleep_pid =~ ^[0-9]+$ ]] && return 0 || return 1
  return 1
}

json_to_array() {
# https://stackoverflow.com/questions/58999047/how-to-construct-associative-bash-array-from-json-hash
  # $1 = variable name of an associative array, ie. "data" from: declare -A data=()
  # $2 = JSON string
  # returns... I don't know but, NOT jq's or read's return code
  [ ! -z "$1" ] && [ ! -z "$2" ] || return 1
  local -n data_ref=$1
  while IFS= read -r -d '' key && IFS= read -r -d '' value; do
      data_ref["$key"]="$value"
  done < <(jq -j 'to_entries[] | (.key, "\u0000", .value, "\u0000")' <<<"$2")
}

array_to_json() {
# https://stackoverflow.com/questions/44792241/constructing-a-json-object-from-a-bash-associative-array
  # $1 = variable name of an associative array, ie. "data" from: declare -A data=()
  # returns jq's return code or possibly printf's return error code
  [ ! -z "$1" ] || return 1
  local -n data_ref=$1
  for key in "${!data_ref[@]}"; do
      printf '%s\0%s\0' "$key" "${data_ref[$key]}" || return $?
  done |
  jq -Rs '
    split("\u0000")
    | . as $a
    | reduce range(0; length/2) as $i
        ({}; . + {($a[2*$i]): ($a[2*$i + 1]|fromjson? // .)})'
}

json_set_key() {
  # sets key/value on root of JSON
  # $1 = input json object
  # $2 = key
  # $3 = value
  # returns jq's return code
  [ ! -z "$1" ] && [ ! -z "$2" ] && [ ! -z "$3" ] || return 1
  if [[ ! $3 =~ ^[0-9]+$ ]]; then
    printf "%s" "$1" | jq ". += {\"$2\": \"$3\"}"
    return $?
  else
    printf "%s" "$1" | jq ". += {\"$2\": $3}"
    return $?
  fi
  return $?
}
