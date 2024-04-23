#!/bin/bash

# The mess down here checks if SSL is enabled.
if is_true "$ENABLE_SSL"; then
	iprint "Configuring lines in qBittorrent.conf for SSL."
	if [[ ${HOST_OS,,} == 'unraid' ]]; then
		iprint "If you use Unraid, and get something like a 'ERR_EMPTY_RESPONSE' in your browser, add https:// to the front of the IP, and/or do this:"
		iprint "Edit this Docker, change the slider in the top right to 'advanced view' and change http to https at the WebUI setting."
	fi
	if [ ! -e "$QCD/WebUICertificate.crt" ]; then
		wprint "WebUI Certificate is missing, generating a new Certificate and Key"
		openssl req -new -x509 -nodes -out "$QCD/WebUICertificate.crt" -keyout "$QCD/WebUIKey.key" -subj "/C=NL/ST=localhost/L=localhost/O=/OU=/CN="
		chown -R ${PUID}:${PGID} "$QCD"
	elif [ ! -e "$QCD/WebUIKey.key" ]; then
		wprint "WebUI Key is missing, generating a new Certificate and Key"
		openssl req -new -x509 -nodes -out "$QCD/WebUICertificate.crt" -keyout "$QCD/WebUIKey.key" -subj "/C=NL/ST=localhost/L=localhost/O=/OU=/CN="
		chown -R ${PUID}:${PGID} "$QCD"
	fi
	if grep -Fxq "WebUI\HTTPS\CertificatePath=$QCD/WebUICertificate.crt" "$QCD/qBittorrent.conf"; then
		iprint "$QCD/qBittorrent.conf already has the line WebUICertificate.crt loaded, nothing to do."
	else
		wprint "$QCD/qBittorrent.conf doesn't have the WebUICertificate.crt loaded. Added it to the config."
		echo "WebUI\HTTPS\CertificatePath=$QCD/WebUICertificate.crt" >> "$QCD/qBittorrent.conf"
	fi
	if grep -Fxq "WebUI\HTTPS\KeyPath=$QCD/WebUIKey.key" "$QCD/qBittorrent.conf"; then
		iprint "$QCD/qBittorrent.conf already has the line WebUIKey.key loaded, nothing to do."
	else
		wprint "$QCD/qBittorrent.conf doesn't have the WebUIKey.key loaded. Added it to the config."
		echo "WebUI\HTTPS\KeyPath=$QCD/WebUIKey.key" >> "$QCD/qBittorrent.conf"
	fi
	if grep -xq 'WebUI\\HTTPS\\Enabled=true\|WebUI\\HTTPS\\Enabled=false' "$QCD/qBittorrent.conf"; then
		if grep -xq 'WebUI\\HTTPS\\Enabled=false' "$QCD/qBittorrent.conf"; then
			wprint "$QCD/qBittorrent.conf does have the WebUI\HTTPS\Enabled set to false, changing it to true."
			sed -i 's/WebUI\\HTTPS\\Enabled=false/WebUI\\HTTPS\\Enabled=true/g' "$QCD/qBittorrent.conf"
		else
			iprint "$QCD/qBittorrent.conf does have the WebUI\HTTPS\Enabled already set to true."
		fi
	else
		wprint "$QCD/qBittorrent.conf doesn't have the WebUI\HTTPS\Enabled loaded. Added it to the config."
		echo 'WebUI\HTTPS\Enabled=true' >> "$QCD/qBittorrent.conf"
	fi
fi
