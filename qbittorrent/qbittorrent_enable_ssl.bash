#!/bin/bash

source "/etc/qbittorrent/qbt_utils.bash"

ME="$(basename "$0")"

qbittorrent_enable_ssl() {
  # $1 = Bittorrent.conf directory, eg. "/config/qBittorrent/config"
  # returns 0 on success, 1 on failure
  [ ! -e "$1" ] && eprint "Cannot edit for SSL. File does not seem to exist: \"$1\"" && return 1
  iprint "Configuring lines in qBittorrent.conf for SSL."
  if [[ ${HOST_OS,,} == 'unraid' ]]; then
    iprint "If you use Unraid, and get something like a 'ERR_EMPTY_RESPONSE' in your browser, add https:// to the front of the IP, and/or do this:"
    iprint "Edit this Docker, change the slider in the top right to 'advanced view' and change http to https at the WebUI setting."
  fi

  if [[ ! -e "$1/WebUICertificate.crt" ||  ! -e "$1/WebUIKey.key" ]]; then
    wprint "The WebUI Certificate or Key is missing, generating a new Certificate and Key."
    openssl req -new -x509 -nodes -out "$1/WebUICertificate.crt" -keyout "$1/WebUIKey.key" -subj "/C=NL/ST=localhost/L=localhost/O=/OU=/CN="
    if [ $? != 0 ]; then
      eprint "$ME: openssl failed to generate WebUICertificate.crt and WebUIKey.key"
      return 1
    fi
  fi

  if cat "$1/qBittorrent.conf" | grep -q '^\[Preferences\][ \t]*$'; then
    # Delete all lines of interest then add the lines back in the "Preferences" section.
    sed -i "/^WebUI\\\HTTPS\\\Enabled=.*$/d" "$1/qBittorrent.conf"
    sed -i "/^WebUI\\\HTTPS\\\KeyPath=.*$/d" "$1/qBittorrent.conf"
    sed -i "/^WebUI\\\HTTPS\\\CertificatePath=.*$/d" "$1/qBittorrent.conf"
    iprint "Setting \"WebUI\HTTPS\CertificatePath=$1/WebUICertificate.crt\" in \"$1/qBittorrent.conf\""
    sed -i "s~^\[Preferences\][ \t]*$~[Preferences\]\nWebUI\\\HTTPS\\\CertificatePath=$1/WebUICertificate.crt~g" "$1/qBittorrent.conf"
    iprint "Setting \"WebUI\HTTPS\KeyPath=$1/WebUIKey.key\" in \"$1/qBittorrent.conf\""
    sed -i "s~^\[Preferences\][ \t]*$~[Preferences\]\nWebUI\\\HTTPS\\\KeyPath=$1/WebUIKey.key~g" "$1/qBittorrent.conf"
    iprint "Setting \"WebUI\HTTPS\Enabled=true\" in \"$1/qBittorrent.conf\""
    sed -i "s~^\[Preferences\][ \t]*$~[Preferences\]\nWebUI\\\HTTPS\\\Enabled=true~g" "$1/qBittorrent.conf"
    
    if cat "$1/qBittorrent.conf" | grep -qF "WebUI\HTTPS\Enabled=true" \
    && cat "$1/qBittorrent.conf" | grep -qF "WebUI\HTTPS\KeyPath=$1/WebUIKey.key" \
    && cat "$1/qBittorrent.conf" | grep -qF "WebUI\HTTPS\CertificatePath=$1/WebUICertificate.crt";
    then
      iprint "SSL configuration added to '$1/qBittorrent.conf'"
      return 0;
    else
      eprint "$ME: sed failed to edit SSL lines in '$1'"
    fi
  else
    eprint "$ME: Can not edit for SSL. Could not find '[Preferences]' section in '$1/qBittorrent.conf'"
  fi
  return 1
}

if ! (return 0 2>/dev/null); then
  qbittorrent_enable_ssl "$@";
  exit $?;
fi
