#!/bin/bash

source "/etc/qbittorrent/qbt_utils.bash"

ME="$(basename "$0")"

start_wireguard_ipv4_only() {
  # $1 : conf file name
  # $2->remaining : line beginnings to search for in CSV, ie "Address,Endpoint"
  if [[ -z "$1" || -z "$2" ]]; then return 1; fi
  for str in $(echo ${@:2}); do
    # grep for the line starting with $str stipping any following '=', tab and space characters
    # ie. if $str == "Address" and the line is "Address = 1.1.1.1/24,ffff:aaaa:eeee:ffff::3:aaa6/128"
    #     then $line will have the value of "1.1.1.1/24,ffff:aaaa:eeee:ffff::3:aaa6/128"
    # local line="$(cat "$1" | grep "^[\t ]*$str[\t ]*=[\t ]*" | sed "s~^[\t ]*$str[\t=\ ]*~~")"
    local line="$(cat "$1" | sed -n "/^[\t ]*$str[\t ]*=[\t ]*/s/^[\t ]*$str[\t ]*=[\t ]*//p")"
    [[ -z "$line" ]] && continue
    # split the CSV into an array of addresses
    local temp=( )
    # timeout read in 3 seconds
    IFS=',' read -t 3 -ra temp <<< "$line"
    local keepers=( )
    local bad=( );
    for el in "${temp[@]}"; do
      # keep the good and bad values
      el=$(trim "$el")
      is_ipv4 "$el" && keepers+=("$el") || bad+=("$el")
    done
    # If there is nothing to keep but only bad values, print and return.
    if [[ ${#keepers[@]} == 0 && ${#bad[@]} -gt 0 ]] then
      eprint "$ME: Did not find any ipv4 addresses for the '$str' line in '$1'. The ${#bad[@]} addresses found were: '${bad[*]}'"
      return 1;
    fi
    if [[ "${#keepers[@]}" -gt 0 ]]; then
      if [[ ${#temp[@]} -gt 1 ]]; then
        # turn the array into a CSV string
        keepers="$(IFS=, ; echo "${keepers[*]}")"
        # replace the entire line with the filtered keeper ipv4's
        iprint "Stripping ipv6 from: $str = $line"
        sed -i "s~^[\t ]*$str[\t ]*=[\t ]*.*$~$str = $keepers~" "$1"
      else
        # If the temp array is < 2, that means there was only 1 address on that
        # line and that address was a valid ipv4 address.
        iprint "Nothing to strip from '$str'. Only 1 ipv4 address: '${keepers[0]}'"
      fi
    fi
  done
  return 0
}
# determine if the script was sourced or not, sourced == true
if ! (return 0 2>/dev/null); then
  start_wireguard_ipv4_only "$@";
  exit $?;
fi