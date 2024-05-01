#!/bin/bash

# exec &> >(tee "$PWD/$(basename "$0").log.txt")

function magnet_forward() (
  # Used with qbittorrent's webserver to add magnet or file links to the queue.
  # Can also save both to a directory. When it's a magnet, the file extension
  # will be .magnet. This can also detect and send those .magnet files.
  #
  # 2024-04-15

  # Usage: ie. In Firefox. Click a magnet link, when it asks to open with what,
  #        choose this scipt. In Firefox in particular, you can also set the
  #        option in Options -> General then under the "Files and Applications"
  #        *.torrent files can also be sent with this script

  # NOTE: If you're using a web browser in something like Ubuntu's snap,
  #       this will not work because cURL, cut, grep, etc. is probably not
  #       packaged with it. You'll have to figure out how to add cURL to the
  #       package.

  # The user and pass of the web login.
  # NOTE: If you enable "Bypass authentication for clients on localhost" or
  #       if you set "Bypass authentication for clients in whitelisted IP
  #       subnets" to your IP, ie. 192.168.0.0/16, then you won't need the
  #       username and password.
  username="admin"
  password="adminadmin"
  # The ip and port that qbittorrent is listening on
  # ip_and_port=omv.local:9090;
  ip_and_port=127.0.0.1:4601;

  # Enforce ".torrent" or ".magnet" to be the last 8 characters of a filename
  # 0 = no, 1 = yes
  enforce_name=1;

  # Write magnets and move torrent files to this directory (magnets are saved
  # with .magnet extension).
  # - does not overwite, uses: mv -n "$source_file" "$torrents_dir"
  # - must be a writeable destination
  # comment out if not in use
  # torrents_dir="$PWD/torrents/";

  if [ ! "$#" -gt "0" ]; then
    >&2 echo "ERROR: requires at least 1 argument, received $#"
    return 1;
  fi

  if [ "$1" == "no_enforce" ]; then
    enforce_name=0;
    shift;
  fi

  # NOTE: You only need to get the "SID" ("Session ID") once each time the
  # script runs, not for every command.

  # Get the "SID" string.
  local sid="$(curl -v -d "username=admin&password=adminadmin" $ip_and_port/api/v2/auth/login  2>&1 | grep -o "SID=[a-AA-Z0-9/\+]\+" | cut -d '=' -f 2)"

  if [ -z "$sid" ]; then
    >&2 echo "ERROR: could not parse SID.";
    return 1;
  fi

  files=( );
  links=( );
  magnets=( );
  temp="";
  for i in "$@"; do
    if [ ! -z "$i" ]; then
      if [ ! -f "$i" ]; then
        # If it's not a file then assume it's a url, what else can be done?
        links+=(-F "urls=$i");
        magnets+=("$i")
      else
        if [ "$enforce_name" == "1" ]; then
          if ! printf "%s" "${i: -8}" | grep -qi ".magnet\|.torrent"; then
            continue;
          fi
        fi
        # Read the file to check if it's a magnet inside.
        temp="$(cat "$i")"
        if printf "%s" "$temp" | grep -iq "^magnet:"; then
          echo "Detected magnet inside of file."
          links+=(-F "urls=$temp");
          magnets+=("$temp")
          continue;
        fi
        links+=(-F "torrents=@$i");
        # Will check the directory when time to write, see below.
        if [ ! -z "$torrents_dir" ]; then
          files+=("$i");
        fi
      fi
    fi
  done

  if [ "${#links[@]}" -gt "0" ]; then
    curl -v -H "Cookie: SID=$sid" -H 'User-Agent: Fiddler' "${links[@]}" $ip_and_port/api/v2/torrents/add
    printf '\n'
    # Need error handling, currently assuming success by always returning 0.
    if [ ! -z "$torrents_dir" ] && [ -w "$torrents_dir" ]; then
      for i in "${files[@]}"; do
        mv -n "$i" "$torrents_dir"
      done
      for j in "${magnets[@]}"; do
        # Decoding the file name from a magnet URL.
        # Find the string '&dn=' taking it and all characters after it.
        # Then, cut at the equal sign '=' and take all characters after '='.
        # Then, replace all plus charcters '+' with space characters ' '.
        # Then, trim leading and trailing whitespace.
        # Then, replace all percentage characters '%' with backslash and x '\x'.
        # Finally, use echo's '-e' switch to interpret \x as implying hex.
        temp="$(printf "%s" "$j" | grep -oi "&dn=.\+" | cut -d '=' -f 2  | sed 's/+/ /g;s/^[ \t]*//;s/[ \t]*$//;s/\%/\\x/g')"
        if [ -z "$temp" ]; then continue; fi
        printf "%s" "$j" > "$torrents_dir/$(echo -e "$temp").magnet"
      done
    elif [ ! -z "$torrents_dir" ]; then
      >&2 echo "Torrents directory is not writeable. Directory: \"$torrents_dir\""
      return 1
    fi
    return 0;
  fi
  return 1;
)

# # Determines if the script was sourced or not.
# # If ! (return 0 2>/dev/null) evaluates to true, then not sourced.
if ! (return 0 2>/dev/null); then
  magnet_forward "$@"
  exit $?;
fi
