#!/bin/bash
install_python3() {
	if [ ! -e /usr/bin/python3 ]; then
		local rc=124
		local timeout_value=60
		if [ "" != "$1" ] && [[ $1 =~ ^[0-9]+$ ]]; then timeout_value=$1; fi
		echo ""
		echo "[INFO] Python3 not yet installed, installing..." | ts '%Y-%m-%d %H:%M:%.S'
		echo ""
		echo "[WARNING] command \"apt update\" will TIMEOUT in $timeout_value seconds." | ts '%Y-%m-%d %H:%M:%.S'
		echo "Running \"apt update\"..." | ts '%Y-%m-%d %H:%M:%.S'
		echo ""
		timeout -k 0 $timeout_value apt update
		rc=$?
		if [ "124" == "$rc" ] || [ "125" == "$rc" ]; then
			echo ""
			echo ""
			echo "[ERROR] \"apt update\" failed or timed out." | ts '%Y-%m-%d %H:%M:%.S'
			echo ""
			return 1
		fi
		echo ""
		echo "[WARNING] command \"apt -y install python3\" will TIMEOUT in $timeout_value seconds." | ts '%Y-%m-%d %H:%M:%.S'
		echo "Running \"apt -y install python3\"..." | ts '%Y-%m-%d %H:%M:%.S'
		echo ""
		timeout -k 0 $timeout_value apt -y install python3
		rc=$?
		if [ "124" == "$rc" ] || [ "125" == "$rc" ]; then
			echo ""
			echo ""
			echo "[ERROR] \"apt -y install python3\" failed or timed out." | ts '%Y-%m-%d %H:%M:%.S'
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
