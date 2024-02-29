# [qBittorrent](https://github.com/qbittorrent/qBittorrent), WireGuard and OpenVPN
[![Docker Pulls](https://img.shields.io/docker/pulls/dyonr/qbittorrentvpn)](https://hub.docker.com/r/dyonr/qbittorrentvpn)
[![Docker Image Size (tag)](https://img.shields.io/docker/image-size/dyonr/qbittorrentvpn/latest)](https://hub.docker.com/r/dyonr/qbittorrentvpn)

Docker container which runs the latest [qBittorrent](https://github.com/qbittorrent/qBittorrent)-nox client while connecting to WireGuard or OpenVPN with iptables killswitch to prevent IP leakage when the tunnel goes down.

[preview]: https://raw.githubusercontent.com/DyonR/docker-templates/master/Screenshots/qbittorrentvpn/qbittorrentvpn-webui.png "qBittorrent WebUI"
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
              -e "VPN_ENABLED=yes" \
              -e "VPN_TYPE=wireguard" \
              -e "LAN_NETWORK=192.168.0.0/24" \
              -p 8080:8080 \
              --cap-add NET_ADMIN \
              --sysctl "net.ipv4.conf.all.src_valid_mark=1" \
              --restart unless-stopped \
              dyonr/qbittorrentvpn
```

## Docker Tags
| Tag | Description |
|----------|----------|
| `dyonr/qbittorrentvpn:latest` | The latest version of qBittorrent with libtorrent 1_x_x |
| `dyonr/qbittorrentvpn:rc_2_0` | The latest version of qBittorrent with libtorrent 2_x_x |
| `dyonr/qbittorrentvpn:legacy_iptables` | The latest version of qBittorrent, libtorrent 1_x_x and an experimental feature to fix problems with QNAP NAS systems, [Issue #25](https://github.com/DyonR/docker-qbittorrentvpn/issues/25) |
| `dyonr/qbittorrentvpn:alpha` | The latest alpha version of qBittorrent with libtorrent 2_0, incase you feel like testing new features |
| `dyonr/qbittorrentvpn:dev` | This branch is used for testing new Docker features or improvements before merging it to the main branch |
| `dyonr/qbittorrentvpn:v4_2_x` | (Legacy) qBittorrent version 4.2.x with libtorrent 1_x_x |

# Variables, Volumes, and Ports
## Environment Variables
| Variable | Required | Function | Example | Default |
|----------|----------|----------|----------|----------|
|`VPN_ENABLED`| Yes | Enable VPN (yes/no)?|`VPN_ENABLED=yes`|`yes`|
|`VPN_TYPE`| Yes | WireGuard or OpenVPN (wireguard/openvpn)?|`VPN_TYPE=wireguard`|`openvpn`|
|`VPN_USERNAME`| No | If username and password provided, configures ovpn file automatically |`VPN_USERNAME=ad8f64c02a2de`||
|`VPN_PASSWORD`| No | If username and password provided, configures ovpn file automatically |`VPN_PASSWORD=ac98df79ed7fb`||
|`LAN_NETWORK`| Yes (atleast one) | Comma delimited local Network's with CIDR notation |`LAN_NETWORK=192.168.0.0/24,10.10.0.0/24`||
|`LEGACY_IPTABLES`| No | Use `iptables (legacy)` instead of `iptables (nf_tables)` |`LEGACY_IPTABLES=yes`||
|`ENABLE_SSL`| No | Let the container handle SSL (yes/no)? |`ENABLE_SSL=yes`|`yes`|
|`NAME_SERVERS`| No | Comma delimited name servers |`NAME_SERVERS=1.1.1.1,1.0.0.1`|`1.1.1.1,1.0.0.1`|
|`PUID`| No | UID applied to /config files and /downloads |`PUID=99`|`99`|
|`PGID`| No | GID applied to /config files and /downloads  |`PGID=100`|`100`|
|`UMASK`| No | |`UMASK=002`|`002`|
|`HEALTH_CHECK_HOST`| No |This is the host or IP that the healthcheck script will use to check an active connection|`HEALTH_CHECK_HOST=one.one.one.one`|`one.one.one.one`|
|`HEALTH_CHECK_INTERVAL`| No |This is the time in seconds that the container waits to see if the internet connection still works (check if VPN died)|`HEALTH_CHECK_INTERVAL=300`|`300`|
|`HEALTH_CHECK_SILENT`| No |Set to `1` to supress the 'Network is up' message. Defaults to `1` if unset.|`HEALTH_CHECK_SILENT=1`|`1`|
|`HEALTH_CHECK_AMOUNT`| No |The amount of pings that get send when checking for connection.|`HEALTH_CHECK_AMOUNT=10`|`1`|
|`RESTART_CONTAINER`| No |Set to `no` to **disable** the automatic restart when the network is possibly down.|`RESTART_CONTAINER=yes`|`yes`|
|`INSTALL_PYTHON3`| No |Set this to `yes` to let the container install Python3.|`INSTALL_PYTHON3=yes`|`no`|
|`ADDITIONAL_PORTS`| No |Adding a comma delimited list of ports will allow these ports via the iptables script.|`ADDITIONAL_PORTS=1234,8112`||
|`VPN_DOWN_FILE` | No | On health check failure, writes "/config/vpn_down" | VPN_DOWN_FILE=yes | no
|`VPN_DOWN_SCRIPT` | No | On health check failure, run "/config/vpn_down.sh" | VPN_DOWN_SCRIPT=yes | no
|`VPN_UP_SCRIPT` | No | On health check success, run "/confing/vpn_up.sh" | VPN_UP_SCRIPT=yes | no
|`VPN_CONF_SWITCH` | No | On health check failure, run bundled conf switch script (read below) | VPN_CONF_SWITCH=yes | no

## Volumes
| Volume | Required | Function | Example |
|----------|----------|----------|----------|
| `config` | Yes | qBittorrent, WireGuard and OpenVPN config files | `/your/config/path/:/config`|
| `downloads` | No | Default downloads path for saving downloads | `/your/downloads/path/:/downloads`|

## Ports
| Port | Proto | Required | Function | Example |
|----------|----------|----------|----------|----------|
| `8080` | TCP | Yes | qBittorrent WebUI | `8080:8080`|
| `8999` | TCP | Yes | qBittorrent TCP Listening Port | `8999:8999`|
| `8999` | UDP | Yes | qBittorrent UDP Listening Port | `8999:8999/udp`|

# Access the WebUI
Access https://IPADDRESS:PORT from a browser on the same network. (for example: https://192.168.0.90:8080)

## Default Credentials

| Credential | Default Value |
|----------|----------|
|`username`| `admin` |
|`password`| `adminadmin` |

# How to use WireGuard 
The container will fail to boot if `VPN_ENABLED` is set and there is no valid .conf file present in the /config/wireguard directory. Drop a .conf file from your VPN provider into /config/wireguard and start the container again. The file must have the name `wg0.conf`, or it will fail to start.

## WireGuard IPv6 issues
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

# VPN_DOWN_SCRIPT and VPN_UP_SCRIPT
Required: An initial successful connection.
Put "`vpn_down.sh`" and/or "`vpn_up.sh`" in the "`/config`" directory. You must make the scripts executable yourself, eg. `chmod` `+x` "`/config/vpn_down.sh`". "`/config/vpn_down.sh`" runs every health check failure and "`/config/vpn_up.sh`" runs every health check success.

# VPN_DOWN_FILE
Required: An initial successful connection.
On health check failure, writes the file "`/config/vpn_down`", no file extension. It will be deleted after a successful connection. It contains a timestamp in the form of: `%Y-%m-%d %H:%M:%.S seconds_since_epoch`

# VPN_CONF_SWITCH
Required: An initial successful connection.
Name your openvpn file "`default.ovpn`" or wireguard file "`wg0.conf`". For openvpn, put this 1 file in "`/config/openvpn/`", for wireguard "`/config/wireguard/`". Put all extra vpn confs in "`/config/openvpn_confs`", for wireguard "`/config/wireguard_confs`". On health check failure, this happens: `cp` `-f` "`/config/openvpn_confs/a_random.ovpn`" "`/config/openvpn/default.ovpn`". The script that is ran is located in the container at "`/scripts/vpn_conf_switch.sh`".

# VPN_CONF_SWITCH_OPENVPN_AT_START=N
At container start and restart, if openvpn hasn't connected after `N` seconds, switch out the "`default.conf`" and then kill and restart `openvpn`. Essentially, if you're going to use `VPN_CONF_SWITCH` with openvpn, then you should use this too. This does not require `VPN_CONF_SWITCH` but, it does use the same script. Make sure to use a large enough value for seconds or the VPN will never connect. The default is 30 seconds if a value is supplied other than a positive integer > 0, "`0`", "`false`" or "`no`". Wireguard works fine with just `VPN_CONF_SWITCH`.

# Issues
If you are having issues with this container please submit an issue on GitHub.  
Please provide logs, Docker version and other information that can simplify reproducing the issue.  
If possible, always use the most up to date version of Docker, you operating system, kernel and the container itself. Support is always a best-effort basis.

### Credits:
[MarkusMcNugen/docker-qBittorrentvpn](https://github.com/MarkusMcNugen/docker-qBittorrentvpn)  
[DyonR/jackettvpn](https://github.com/DyonR/jackettvpn)  
This projects originates from MarkusMcNugen/docker-qBittorrentvpn, but forking was not possible since DyonR/jackettvpn uses the fork already.
