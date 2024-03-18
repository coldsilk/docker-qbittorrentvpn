#!/bin/bash
install_python3() {
	if [ ! -e /usr/bin/python3 ]; then
		local rc=124
		local timeout_value=60
		if [ "" != "$1" ] && [[ $1 =~ ^[0-9]+$ ]]; then timeout_value=$1; fi
		echo ""
		echo "[INFO] Python3 not yet installed, installing..." | ts '%Y-%m-%d %H:%M:%.S'
		echo ""
  		# without sleep, apt update may fail to connect when using OpenVPN (maybe wireguard too), not sure why yet
		sleep 5
		echo ""
		echo "[WARNING] command \"apt update\" will TIMEOUT in $timeout_value seconds." | ts '%Y-%m-%d %H:%M:%.S'
		echo ""
		echo "[INFO] Running \"apt update\"..." | ts '%Y-%m-%d %H:%M:%.S'
		echo ""
		timeout -k 0 $timeout_value apt update
		rc=$?
		if [ "124" == "$rc" ] || [ "125" == "$rc" ] || [ "143" == "$rc" ]; then
			echo ""
			echo ""
			echo "[ERROR] \"apt update\" failed or timed out with code $rc." | ts '%Y-%m-%d %H:%M:%.S'
			echo ""
			return 1
		fi
		timeout_value=$(($timeout_value + 60))
		echo ""
		echo "[WARNING] command \"apt -y install python3\" will TIMEOUT in $timeout_value seconds." | ts '%Y-%m-%d %H:%M:%.S'
		echo ""
		echo "[INFO] Running \"apt -y install python3\"..." | ts '%Y-%m-%d %H:%M:%.S'
		echo ""
		timeout -k 0 $timeout_value apt -y install python3
		rc=$?
		if [ "100" == "$rc" ]; then
			echo ""
			echo ""
			echo "[ERROR] \"apt -y install python3\" failed with code $rc." | ts '%Y-%m-%d %H:%M:%.S'
			echo ""
			return 1
		fi
		echo ""
		if [ -e /usr/bin/python3 ]; then
			echo ""
			echo "[INFO] Python3 installed successfully." | ts '%Y-%m-%d %H:%M:%.S'
			echo ""
		else
			echo ""
			echo ""
			echo "[ERROR] _PYTHON_3_FAILED_TO_INSTALL_" | ts '%Y-%m-%d %H:%M:%.S'
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
		echo "[INFO] Python3 is already installed, nothing to do." | ts '%Y-%m-%d %H:%M:%.S'
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
