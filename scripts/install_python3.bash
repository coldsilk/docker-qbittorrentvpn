#!/bin/bash

source "/scripts/printers.bash"

install_python3() {
	if [ ! -e /usr/bin/python3 ]; then
		local rc=124
		local timeout_value=60
		if [ "" != "$1" ] && [[ $1 =~ ^[0-9]+$ ]]; then timeout_value=$1; fi
		echo ""
		iprint "Python3 not yet installed, installing..."
		echo ""
  		# without sleep, apt update may fail to connect when using OpenVPN (maybe wireguard too), not sure why yet
		sleep 5
		echo ""
		wprint "Command \"apt update\" will TIMEOUT in $timeout_value seconds."
		echo ""
		iprint "Running \"apt update\"..."
		echo ""
		timeout -k 0 $timeout_value apt update
		rc=$?
		if [ "124" == "$rc" ] || [ "125" == "$rc" ] || [ "143" == "$rc" ]; then
			echo ""
			echo ""
			eprint "\"apt update\" failed or timed out with code $rc."
			echo ""
			return 1
		fi
		timeout_value=$(($timeout_value + 60))
		echo ""
		wprint "Command \"apt -y install python3\" will TIMEOUT in $timeout_value seconds."
		echo ""
		iprint "Running \"apt -y install python3\"..."
		echo ""
		timeout -k 0 $timeout_value apt -y install python3
		rc=$?
		if [ "100" == "$rc" ]; then
			echo ""
			echo ""
			eprint "\"apt -y install python3\" failed with code $rc."
			echo ""
			return 1
		fi
		echo ""
		if [ -e /usr/bin/python3 ]; then
			echo ""
			iprint "Python3 installed successfully."
			echo ""
		else
			echo ""
			echo ""
			eprint "_PYTHON_3_FAILED_TO_INSTALL_"
			echo ""
			echo ""
			echo ""
			return 1
		fi
		apt-get clean \
		&& apt -y autoremove \
		&& rm -rf \
		/var/lib/apt/lists/* \
		/tmp/* \
		/var/tmp/*
		return 0
	else
		echo ""
		iprint "Python3 is already installed, nothing to do."
		echo ""
		return 0
	fi
	return 1
}

# # determines if the script was sourced or not
# # if ! (return 0 2>/dev/null) evaluates to true, then not sourced
if ! (return 0 2>/dev/null); then
  install_python3 "$@"
  exit $?;
fi

# # NOTE: No longer used as of 2024-04-18ymd
# # python3 is now a built-in for the Docker image by default
# # below was the caller of install_python3()
# # INSTALL_PYTHON3 used to be a docker run/compose env variable
# export INSTALL_PYTHON3=$(echo "${INSTALL_PYTHON3,,}")
# if is_true "$INSTALL_PYTHON3"; then
# 	/bin/bash /etc/qbittorrent/install_python3.sh
#   	# NOTE: In order for the torrent search in qbittorrent to work, you need python3
# 	if ! which python3 > /dev/null; then
# 			echo ""
# 			echo ""
# 			echo ""
# 			eprint "$ME: _PYTHON_3_FAILED_TO_INSTALL_"
# 			echo ""
# 			echo ""
# 			echo ""
# 	fi
# fi
