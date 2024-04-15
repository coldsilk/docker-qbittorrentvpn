# [qBittorrent](https://github.com/qbittorrent/qBittorrent), WireGuard and OpenVPN
[![Docker Pulls](https://img.shields.io/docker/pulls/coldsilk/docker-qbittorrent)](https://hub.docker.com/r/coldsilk/docker-qbittorrent)
[![Docker Image Size (tag)](https://img.shields.io/docker/image-size/coldsilk/docker-qbittorrent/latest)](https://hub.docker.com/r/coldsilk/docker-qbittorrent)

### Version 1.2.1

Docker container which runs the latest [qBittorrent](https://github.com/qbittorrent/qBittorrent)-nox client while connecting to WireGuard or OpenVPN with iptables killswitch to prevent IP leakage when the tunnel goes down. Also a automatic VPN conf switcher incase you have a free/unstable VPN.

[preview]: qbittorrentvpn-webui.png "qBittorrent WebUI"
![alt text][preview]

# Docker Features
* Base: Debian bullseye-slim
* [qBittorrent](https://github.com/qbittorrent/qBittorrent) compiled from source
* [libtorrent](https://github.com/arvidn/libtorrent) compiled from source
* Compiled with the latest version of [Boost](https://www.boost.org/)
* Compiled with the latest versions of [CMake](https://cmake.org/)
* Selectively enable or disable WireGuard or OpenVPN support
* IP tables killswitch to prevent IP leaking when VPN connection fails
* Configurable UID and GID for config files and /downloads for qBittorrent
* Created with [Unraid](https://unraid.net/) in mind
* BitTorrent port 8999 exposed by default

## Run container from Docker registry
The container is available from the Docker registry and this is the simplest way to get it  
To run the container use this command, with additional parameters, please refer to the Variables, Volumes, and Ports section:

```
$ docker run  -d \
              -v /your/config/path/:/config \
              -v /your/downloads/path/:/downloads \
              -e "VPN_TYPE=wireguard" \
              -e "LAN_NETWORK=192.168.0.0/16" \
              `# 8080 default host port for webui, but it can be changed` \
              -e "QBT_WEBUI_PORT=8080" \
              -p 8080:8080 \
              `# 8999 default host port for torrents, but it can be changed` \
              -e "TORRENT_PORT=8999" \
              -p 8999:8999 \
              -p 8999:8999/udp \
              --cap-add NET_ADMIN \
              --sysctl "net.ipv4.conf.all.src_valid_mark=1" \
              --restart unless-stopped \
              coldsilk/docker-qbittorrent:latest
```

## Docker Tags
| Tag | Description |
|----------|----------|
| `coldsilk/docker-qbittorrent:latest` | The latest version of qBittorrent with libtorrent 1_x_x |

## To create the image and run the container from this git
```
Download and extract the zip file or clone with:
$ git clone https://github.com/coldsilk/docker-qbittorrentvpn
then...
$ cd docker-qbittorrentvpn
$ docker build -t yourtagname .
Now create the container as normal but with yourtagname
at the end instead of coldsilk/docker-qbittorrent:latest
$ docker run -d \
              ... \
              ... \
              yourtagname
```

# Variables, Volumes, and Ports
## Environment Variables
| Variable | Required | Function | Example | Default |
|----------|----------|----------|----------|----------|
|`VPN_ENABLED`| Yes | Enable VPN (yes/no)?|`VPN_ENABLED=yes`|`yes`|
|`VPN_TYPE`| Yes | WireGuard or OpenVPN (wireguard/openvpn)?|`VPN_TYPE=wireguard`|`openvpn`|
|`QBT_WEBUI_PORT`| No | Sets the WebUI port for qBittorrent|`QBT_WEBUI_PORT=8080`|`8080`|
|`QBT_TORRENTING_PORT`| No | Sets the torrent port for qBittorrent|`QBT_TORRENTING_PORT=8999`|`8999`|
|`SHUTDOWN_WAIT`| No | On healtch check failures or kill -6 1, seconds to wait for qBittorent to shutdown before exiting|`SHUTDOWN_WAIT=30`|`30`|
|`VPN_USERNAME`| No | If username and password provided, configures ovpn file automatically |`VPN_USERNAME=ad8f64c02a2de`||
|`VPN_PASSWORD`| No | If username and password provided, configures ovpn file automatically |`VPN_PASSWORD=ac98df79ed7fb`||
|`LAN_NETWORK`| Yes (at least one) | Comma delimited local Network's with CIDR notation |`LAN_NETWORK=192.168.0.0/24,10.10.0.0/24`||
|`LEGACY_IPTABLES`| No | Use `iptables (legacy)` instead of `iptables (nf_tables)` |`LEGACY_IPTABLES=yes`||
|`ENABLE_SSL`| No | Let the container handle SSL (yes/no)? |`ENABLE_SSL=yes`|`yes`|
|`NAME_SERVERS`| No | Comma delimited name servers |`NAME_SERVERS=37.235.1.174,1.1.1.1`|`37.235.1.174,84.200.69.80,1.1.1.1,84.200.70.40,1.0.0.1,37.235.1.177`|
|`PUID`| No | UID applied to /config files and /downloads |`PUID=99`|`99`|
|`PGID`| No | GID applied to /config files and /downloads  |`PGID=100`|`100`|
|`UMASK`| No | |`UMASK=002`|`002`|
|`HEALTH_CHECK_HOST`| Yes (at least one) |The host(s) used to check for an active connection, it can be a comma seperated list|`HEALTH_CHECK_HOST=1.1.1.1,84.200.69.80`|`1.1.1.1,84.200.69.80`|
|`HEALTH_CHECK_INTERVAL`| No |This is the time in seconds that the container waits to see if the internet connection still works (check if VPN died)|`HEALTH_CHECK_INTERVAL=30`|`30`|
| `HEALTH_CHECK_FAILURES`| No |The amount of intervals that have to fail before a restart can happen. If HEALTH_CHECK_INTERVAL=30 and this is 3, then ~90 seconds (+ ping time * hosts).|`HEALTH_CHECK_FAILURES=3`|`3`|
|`HEALTH_CHECK_SILENT`| No |Set to `1` to supress the 'Network is up' message. Defaults to `1` if unset.|`HEALTH_CHECK_SILENT=1`|`1`|
|`HEALTH_CHECK_AMOUNT`| No |The amount of pings that get send when checking for connection.|`HEALTH_CHECK_AMOUNT=3`|`3`|
|`RESTART_CONTAINER`| No |Set to `no` to **disable** the automatic restart when the network is possibly down.|`RESTART_CONTAINER=yes`|`yes`|
|`INSTALL_PYTHON3`| No |Set this to `yes` to let the container install Python3.|`INSTALL_PYTHON3=yes`|`no`|
|`ADDITIONAL_PORTS`| No |Adding a comma delimited list of ports will allow these ports via the iptables script.|`ADDITIONAL_PORTS=1234,8112`||
|`VPN_DOWN_FILE` | No | On health check failure, writes "/config/vpn_down" | VPN_DOWN_FILE=yes | no
|`VPN_DOWN_SCRIPT` | No | On health check failure, run "/config/vpn_down.sh" | VPN_DOWN_SCRIPT=yes | no
|`VPN_UP_SCRIPT` | No | On health check success, run "/confing/vpn_up.sh" | VPN_UP_SCRIPT=yes | no
|`VPN_CONF_SWITCH` | No | On health check failure, run bundled conf switch script (read below) | VPN_CONF_SWITCH=yes | yes
|`VPN_CONF_SWITCH_OPENVPN_AT_START` | No | Restart OpenVPN with a new conf after n seconds | VPN_CONF_SWITCH_OPENVPN_AT_START=30 | 30 seconds

## Volumes
| Volume | Required | Function | Example |
|----------|----------|----------|----------|
| `config` | Yes | qBittorrent, WireGuard and OpenVPN config files | `/your/config/path/:/config`|
| `downloads` | No | Default downloads path for saving downloads | `/your/downloads/path/:/downloads`|

## Ports
The QBT_WEBUI_PORT works but, if it's changed within qBittorrent itself, you may no longer be able to connect to the webui (the connection will probably time out).    
# 
| Port | Proto | Required | Function | Example |
|----------|----------|----------|----------|----------|
| `8080` | TCP | Yes | qBittorrent WebUI | `8080:8080`|
| `8999` | TCP | Yes | qBittorrent TCP Listening Port | `8999:8999`|
| `8999` | UDP | Yes | qBittorrent UDP Listening Port | `8999:8999/udp`|

# Access the WebUI
Access https://IPADDRESS:PORT from a browser on the same network. For example: https://192.168.0.90:8080. Or, to access on the same computer, localhost:8080 or 127.0.0.1:8080.

## Default Credentials

| Credential | Default Value |
|----------|----------|
|`username`| `admin` |
|`password`| `adminadmin` |

# How to use WireGuard 
The container will fail to boot if `VPN_ENABLED` is set and there is no valid .conf file present in the /config/wireguard directory. Drop a .conf file from your VPN provider into /config/wireguard and start the container again. The file must have the name `wg0.conf`, or it will fail to start.

## WireGuard IPv6 issues
By default WG_CONF_IPV4_ONLY=1 which removes all invalid ipv4 addresses from the 4 lines beginning with "Address=", "DNS=", "AllowedIPs=" and "Endpoint=". It must be set to anything other than 1 to use ipv6, eg. WG_CONF_IPV4_ONLY=0.  
If you use WireGuard and also have IPv6 enabled, it is necessary to add the IPv6 range to the `LAN_NETWORK` environment variable.  
Additionally the parameter `--sysctl net.ipv6.conf.all.disable_ipv6=0` also must be added to the `docker run` command, or to the "Extra Parameters" in Unraid.  
The full Unraid `Extra Parameters` would be: `--restart unless-stopped --sysctl net.ipv6.conf.all.disable_ipv6=0"`  
If you do not do this, the container will keep on stopping with the error `RTNETLINK answers permission denied`.
Since I do not have IPv6, I am did not test.
Thanks to [mchangrh](https://github.com/mchangrh) / [Issue #49](https://github.com/DyonR/docker-qbittorrentvpn/issues/49)  

# How to use OpenVPN
The container will fail to boot if `VPN_ENABLED` is set and there is no valid .ovpn file present in the /config/openvpn directory. Drop a .ovpn file from your VPN provider into /config/openvpn (if necessary with additional files like certificates) and start the container again. You may need to edit the ovpn configuration file to load your VPN credentials from a file by setting `auth-user-pass`.

**Note:** The script will use the first ovpn file it finds in the /config/openvpn directory. Adding multiple ovpn files will not start multiple VPN connections.

## Example auth-user-pass option for .ovpn files
`auth-user-pass credentials.conf`

## Example credentials.conf
```
username
password
```

## PUID/PGID
User ID (PUID) and Group ID (PGID) can be found by issuing the following command for the user you want to run the container as:

```
id <username>
```

## VPN_DOWN_SCRIPT and VPN_UP_SCRIPT
Put "`vpn_down.sh`" and/or "`vpn_up.sh`" in the "`/config`" directory. You must make the scripts executable yourself, eg. `chmod` `+x` "`/config/vpn_down.sh`". "`/config/vpn_down.sh`" runs every health check failure and "`/config/vpn_up.sh`" runs every health check success.

## VPN_DOWN_FILE
On health check failure, writes the file "`/config/vpn_down`", no file extension. This is an external way to observe the VPN state. It will be deleted after a successful connection. It contains a timestamp in the form of: `%Y-%m-%d %H:%M:%.S seconds_since_epoch`

## VPN_CONF_SWITCH (default: enabled)
Name your openvpn file "`default.ovpn`" or wireguard file "`wg0.conf`". For openvpn, put this 1 file in "`/config/openvpn/`", for wireguard "`/config/wireguard/`". Put all extra vpn confs in "`/config/openvpn_confs`", for wireguard "`/config/wireguard_confs`". On health check failure, this happens: `cp` `-f` "`/config/openvpn_confs/a_random.ovpn`" "`/config/openvpn/default.ovpn`". The script that is ran is located in the container at "`/scripts/vpn_conf_switch.sh`". To disable, set this to "`0`", "`false`" or "`no`". This is a benign option because if the extra confs directory doesn't exist or is empty, then nothing happens but a message.

## VPN_CONF_SWITCH_OPENVPN_AT_START=N (default: enabled and set to 30)
At container start and restart, if openvpn hasn't connected after `N` seconds, switch out the "`default.conf`" and then kill and restart `openvpn`. Essentially, if you're going to use `VPN_CONF_SWITCH` with openvpn, then you should use this too or `openvpn` may never connect if the VPN or conf is bad. This does not require `VPN_CONF_SWITCH` but, it does use the same script. Make sure to use a large enough value for seconds or the VPN will never connect. The default is 30 seconds if a value is supplied other than a positive integer > 0, "`0`", "`false`" or "`no`". Wireguard works fine with just `VPN_CONF_SWITCH`. This is a benign option because if the extra confs directory doesn't exist or is empty, then nothing happens but a message.

# Issues
If you are having issues with this container please submit an issue on GitHub.  
Please provide logs, Docker version and other information that can simplify reproducing the issue.  
If possible, always use the most up to date version of Docker, your operating system, kernel and the container itself. Support is always a best-effort basis.

### Credits:
[MarkusMcNugen/docker-qBittorrentvpn](https://github.com/MarkusMcNugen/docker-qBittorrentvpn)  
[DyonR/jackettvpn](https://github.com/DyonR/jackettvpn)  
[coldsilk/docker-qBittorrentvpn](https://github.com/coldsilk/docker-qBittorrentvpn)  
This projects originates from MarkusMcNugen/docker-qBittorrentvpn, but forking was not possible since DyonR/jackettvpn uses the fork already.
