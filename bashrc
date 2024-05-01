# ~/.bashrc: executed by bash(1) for non-login shells.

# Note: PS1 and umask are already set in /etc/profile. You should not
# need this unless you want different defaults for root.
# PS1='${debian_chroot:+($debian_chroot)}\h:\w\$ '
# umask 022

# You may uncomment the following lines if you want `ls' to be colorized:
# export LS_OPTIONS='--color=auto'
# eval "$(dircolors)"
# alias ls='ls $LS_OPTIONS'
# alias ll='ls $LS_OPTIONS -l'
# alias l='ls $LS_OPTIONS -lA'
#
# Some more alias to avoid making mistakes:
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Personal aliases

alias myip='curl ifconfig.io'
alias x='exit'
alias qconf='cat /config/qbittorrent/qBittorrent/config/qBittorrent.conf'
alias qlog='cat /config/qbittorrent/qBittorrent/data/logs/qbittorrent.log'
alias fixdownloads='fixdownloads(){ [ -z ${1} ] && _PUID=${PUID} || _PUID=${1}; [ -z ${2} ] && _PGID=${PGID} || _PGID=${2}; find /downloads -not -user ${_PUID} -execdir chown ${_PUID}:${_PGID} {} \+; };fixdownloads'
alias reboot='echo "Shutting down..."; kill -SIGTERM 1'
alias restart='echo "Shutting down..."; kill -SIGTERM 1'
alias shutdown='echo "Shutting down..."; kill -SIGTERM 1'
