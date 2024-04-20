# [qBittorrent](https://github.com/qbittorrent/qBittorrent), WireGuard and OpenVPN
[![Docker Pulls](https://img.shields.io/docker/pulls/coldsilk/docker-qbittorrent)](https://hub.docker.com/r/coldsilk/docker-qbittorrent)
[![Docker Image Size (tag)](https://img.shields.io/docker/image-size/coldsilk/docker-qbittorrent/latest)](https://hub.docker.com/r/coldsilk/docker-qbittorrent)

<h2 id="version">Version 1.2.2 (2024-04-19)</h2>

Docker container which runs the latest [qBittorrent](https://github.com/qbittorrent/qBittorrent)-nox client while connecting to WireGuard or OpenVPN with iptables killswitch to prevent IP leakage when the tunnel goes down with an automatic VPN conf switcher incase you have a free/unstable VPN.

<h2 id="coldsilk_added_features">Things added on coldsilk fork</h2>

* Option of a VPN conf switcher incase you have a free/unstable VPN [(read notes)](#notes_vpn_conf_switch)
* Shutdown of qBittorrent with cURL to save downloaded torrent data. This is also apparently important for trackers that you want to collect your usage such as quota based private trackers [(read notes)](#notes_shutdown)
* Option to set the "Network Interface:" inside qBittorrent to the VPN adapter, ie. wg0 or tun0 or tap0
* Option to use OpenVPN without having a "credentials.conf" file [(read notes)](#how_openvpn)
* Option to change qBittorrent's Web UI port and Torrenting port
* Health check can now go N ping failures to N servers before restarting [(read notes)](#notes_on_health_check)
* Default username and password is back to admin/adminadmin
* Option to auto-strip ipv6 addresses in wg0.conf [(read notes)](#how_wireguard)
* Option to write a file to /config while the internet is seemingly down[(read notes)](#notes_vpn_down_file)  
* Option to run a script when the health check succeeds and/or fails [(read notes)](#notes_up_down_scripts)  
* Added a simple .bash script to send .torrents and magnets (it's copied to /config)
* Added a reaper to restart the container if not connected by N seconds (default: 30).
* Option to move the VPN config files into the container [(read notes)](#notes_move_configs)  
* Option to pass VPN options to OpenVPN
* Option to set timezone
  
<h2 id="coldsilk_changes">Things changed on coldsilk fork</h2>

* Python3 is now a built-in. I think it's a reasonable user expectation to have full GUI functionality.

NOTE: I don't use ipv6 or SSL so I haven't tried either with this container, not once.

<br/><br/>

[preview]: qbittorrentvpn-webui.jpg "qBittorrent WebUI"
![alt text][preview]   

<h2 id="pre-coldsilk_features">Existing pre-coldsilk fork features</h2>

* Base: Debian bullseye-slim
* [qBittorrent](https://github.com/qbittorrent/qBittorrent) compiled from source
* [libtorrent](https://github.com/arvidn/libtorrent) compiled from source
* Compiled with the latest version of [Boost](https://www.boost.org/)
* Compiled with the latest version of [CMake](https://cmake.org/)
* Selectively enable or disable WireGuard or OpenVPN
* IP tables killswitch to prevent IP leaking when VPN connection fails
* Configurable UID and GID for config files and /downloads for qBittorrent
* BitTorrent port 8999 exposed by default

<h2 id="run_from_docker_registry">Run container from Docker registry</h2>

The container is available from the Docker registry and this is the simplest way to get it  
To run the container use this command, with additional parameters, please refer to the Variables, Volumes, and Ports section:

```
$ docker run  -d \
              -v /your/config/path/:/config \
              -v /your/downloads/path/:/downloads \
              -e "VPN_TYPE=openvpn" \
              -e "TZ=Etc/UTC" \
              -e "LAN_NETWORK=192.168.0.0/16" \
              -e "QBT_WEBUI_PORT=8080" \
              -p 8080:8080 \
              -e "QBT_TORRENTING_PORT=8999" \
              -p 8999:8999 \
              -p 8999:8999/udp \
              --cap-add NET_ADMIN \
              --device=/dev/net/tun \
              --sysctl "net.ipv4.conf.all.src_valid_mark=1" \
              --restart unless-stopped \
              coldsilk/docker-qbittorrent:latest
```

<h2 id="docker_tags">Docker Tags</h2>

| Tag | Description |
|----------|----------|
| `coldsilk/docker-qbittorrent:latest` | The latest version of qBittorrent with libtorrent 1_x_x |

<h2 id="build_container">To create the image and run the container from this git</h2>

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

<br/><br/>

<h1 id="variables_volumes_ports">Variables, Volumes, and Ports</h1>

<h2 id="environment_variables">Environment Variables</h2>

<h2 id="example_is_default">The example is the default. 0 = No, 1 = Yes</h2>

| Variable | Required | Function | Example 
|----------|----------|----------|----------|
|`VPN_ENABLED` | Yes | Enable VPN? | `VPN_ENABLED=1`
|`VPN_TYPE` | Yes | WireGuard or OpenVPN (wireguard/openvpn)? | `VPN_TYPE=openvpn`
|`REAP_WAIT` | Yes | Restart if not connected by n seconds. VPN_CONF_SWITCH is observed. | `REAP_WAIT=30`
|`VPN_CONF_SWITCH` | No | On health check or startup failures, switch conf/ovpn file. [(read notes)](#notes_vpn_conf_switch) | `VPN_CONF_SWITCH=1`
|`MOVE_CONFIGS` | No | Move VPN config files into the container. | `MOVE_CONFIGS=0`
|`QBT_WEBUI_PORT` | No | Sets the WebUI port for qBittorrent. | `QBT_WEBUI_PORT=8080`
|`QBT_TORRENTING_PORT` | No | Sets the torrent port for qBittorrent. | `QBT_TORRENTING_PORT=8999`
|`SHUTDOWN_WAIT` | Yes | After health check failures or kill -6 1, n seconds to wait for qBittorent to shutdown before kill -9. | `SHUTDOWN_WAIT=30`
|`TZ` | No | Timezone. Choose from column "TZ identifier" here [List of tz database time zones](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones#List). | `TZ=Etc/UTC`
|`VPN_USERNAME` | No | If username and password are set, configures ovpn file automatically. | `VPN_USERNAME=(empty)`
|`VPN_PASSWORD` | No | If username and password are set, configures ovpn file automatically. | `VPN_PASSWORD=(empty)`
|`VPN_OPTIONS` | No | Options for OpenVPN. Comma delimited. | `VPN_OPTIONS=(empty)`
|`_QBT_USERNAME` | No | Read [notes on SHUTDOWN_WAIT](#notes_shutdown). | `_QBT_USERNAME=admin`
|`_QBT_PASSWORD` | No | Read [notes on SHUTDOWN_WAIT](#notes_shutdown). | `_QBT_PASSWORD=adminadmin`
|`QBT_SET_INTERFACE` | No | Sets the "Network Inerface:" in qBittorrent to wg0, tun0 or tap0. | `QBT_SET_INTERFACE=1`
|`OVPN_NO_CRED_FILE` | No | Do not use credentials.conf file with OpenVPN; deletes all "auth-user-pass" lines from *.ovpn files. | `OVPN_NO_CRED_FILE=0`
|`WG_CONF_IPV4_ONLY` | No | Remove all invalid ipv4 addresses from the lines defined by WG_CONF_IPV4_LINES in wg0.conf. | `WG_CONF_IPV4_ONLY=1`
|`WG_CONF_IPV4_LINES` | No | Line starting words to parse for removing invalid ipv4 addresses in wg0.conf. | `WG_CONF_IPV4_LINES="Address,DNS,AllowedIPs,Endpoint"`
|`LAN_NETWORK` | Yes | Local Network's with CIDR notation. Comma delimited. | `LAN_NETWORK="192.168.0.0/16,10.0.0.0/8"`
|`LEGACY_IPTABLES` | No | Use iptables (legacy) instead of iptables (nf_tables). | `LEGACY_IPTABLES=0`
|`ENABLE_SSL` | No | Let the container handle SSL. | `ENABLE_SSL=1`
|`NAME_SERVERS` | Yes | Name serviers. Comma delimited. | `NAME_SERVERS="1.1.1.1,37.235.1.174,84.200.69.80,84.200.70.40,1.0.0.1,37.235.1.177"`
|`PUID` | Yes | UID applied to /config files and /downloads. | `PUID="1000"`
|`PGID` | Yes | GID applied to /config files and /downloads. | `PGID="1000"`
|`UMASK` | Yes | |`UMASK="002"`
|`HEALTH_CHECK_HOST` | Yes | The host(s) used to check for an active connection, it can be a comma seperated list. [(read notes)](#notes_on_health_check) | `HEALTH_CHECK_HOST="1.1.1.1,84.200.69.80"`
|`HEALTH_CHECK_INTERVAL` | Yes | This is the time in seconds that the container waits to see if the internet connection has died. [(read notes)](#notes_on_health_check) | `HEALTH_CHECK_INTERVAL=30`
| `HEALTH_CHECK_FAILURES` | Yes | The amount of intervals that have to fail before a restart can happen. [(read notes)](#notes_on_health_check) | `HEALTH_CHECK_FAILURES=3`
|`HEALTH_CHECK_AMOUNT` | Yes | The amount of packets ping sends. [(read notes)](#notes_on_health_check) | `HEALTH_CHECK_AMOUNT=3`
|`HEALTH_CHECK_PING_TIME` | Yes | Timeout ping after N seconds. [(read notes)](#notes_on_health_check) | `HEALTH_CHECK_PING_TIME=15`
|`HEALTH_CHECK_SILENT` | No | Set to 1 to supress the 'Network is up' message. | `HEALTH_CHECK_SILENT=1`
|`RESTART_CONTAINER` | No | Set to 0 to **disable** the automatic restart when the network is possibly down. | `RESTART_CONTAINER=1`
|`ADDITIONAL_PORTS` | No | List to allow via iptables. Comma delimited. | `ADDITIONAL_PORTS=(empty)`
|`VPN_DOWN_FILE` | No | On health check failure, writes "/config/vpn_down". | `VPN_DOWN_FILE=0`
|`VPN_DOWN_SCRIPT` | No | On health check failure, run "/config/vpn_down.sh". | `VPN_DOWN_SCRIPT=0`
|`VPN_UP_SCRIPT` | No | On health check success, run "/confing/vpn_up.sh". | `VPN_UP_SCRIPT=0`

<h2 id="volumes">Volumes</h2>

| Volume | Required | Function | Example |
|----------|----------|----------|----------|
| `config` | Yes | qBittorrent, WireGuard and OpenVPN config files | `/your/config/path/:/config`|
| `downloads` | No | Default downloads path for saving downloads | `/your/downloads/path/:/downloads`|

<h2 id="ports">Ports</h2>

The `QBT_WEBUI_PORT` works but, if it's changed within qBittorrent itself, you may no longer be able to connect to the Web UI.    

| Port | Proto | Required | Function | Example |
|----------|----------|----------|----------|----------|
| `8080` | TCP | Yes | qBittorrent WebUI | `8080:8080`|
| `8999` | TCP | Yes | qBittorrent TCP Listening Port | `8999:8999`|
| `8999` | UDP | Yes | qBittorrent UDP Listening Port | `8999:8999/udp`|

<h1 id="access_the_webui">Access the WebUI</h1>

Access https://IPADDRESS:PORT from a browser on the same network. For example: https://192.168.0.90:8080. Or, to access on the same computer, localhost:8080 or 127.0.0.1:8080.

<h2 id="default_credentials"">Default Credentials</h2>

| Credential | Default Value |
|----------|----------|
|`username`| `admin` |
|`password`| `adminadmin` |

<br/><br/>

<h1 id="notes_shutdown">Notes on SHUTDOWN_WAIT</h1>

<h3 id="curl_shutdown">Using `curl` to shutdown qBittorrent is the only way I know of to avoid loss of download data.</h3>

__Requires__: 
1. "Bypass authentication for clients on localhost" (under the "Web UI" tab)
2. or "Bypass authentication for clients in whitelisted IP subnets" (under the "Web UI" tab)
3. or Setting `_QBT_USERNAME` and `_QBT_PASSWORD`. 

By default, local host access is enabled in the qBittorrent.conf file with the line `WebUI\LocalHostAuth=false` and whitelisted IPs are enabled by the line `WebUI\AuthSubnetWhitelist=192.168.0.0/16, 10.0.0.0/8`.   
If the `curl` command fails the request, SIGABRT is used.
If `SHUTDOWN_WAIT` is reached, the script uses kill -9 and exits with code 99   
Internally, cURL shut downs happen on health check failures or by sending SIGABRT to process 1 in the container.  
Externally, restart the container with `docker restart` with a long enough timeout, ie __`docker restart -s SIGABRT -t 180 qbittorrent`__  
To stop the container, use `docker stop` with a long enough timeout, ie. __`docker stop -s SIGABRT -t 180 qbittorrent`__  
Utimately, if the trap is triggered, 2 or 3 cURL related commands happen.
1. `curl -v -d "username=$_QBT_USERNAME&password=$_QBT_PASSWORD" -X POST 127.0.0.1:$QBT_WEBUI_PORT/api/v2/auth/login"`
2. `curl -v -H "Cookie: SID=$sid" -X POST 127.0.0.1:$QBT_WEBUI_PORT/api/v2/app/shutdown`
3. `curl -v -d "" 127.0.0.1:$QBT_WEBUI_PORT/api/v2/app/shutdown`  

Command 1. gets the SID string, 2. tries to shut down using POST, 3. only happens if 2. fails and it solely exists in case you're bypassing authentication and the sid won't parse (notice there's no username or password for 3.).  
If the curl command succeeds, then it waits on the process to exit or until `SHUTDOWN_WAIT` is reached.  
If the curl command fails, SIGABRT is sent immediately and waits on the process to exit or until `SHUTDOWN_WAIT` is reached.  
Some trackers will want to collect data usage, so if you care about that because you use private trackers or something else, set the value for `SHUTDOWN_WAIT` pretty high. Most of the time during a shutdown will be allocated to disconnecting, not saving the torrent data, which happens quickly.   
Reference: https://docs.docker.com/reference/cli/docker/container/stop/

<br/><br/>

<h1 id="how_wireguard">How to use WireGuard</h1>

The container will fail to boot if `VPN_ENABLED` is set and there is no valid .conf file present in the /config/wireguard directory. The file must have the name `wg0.conf`, or it will fail to start.

<h2 id="wireguard_ipv6">WireGuard IPv6 issues</h2>

By default, `WG_CONF_IPV4_ONLY` is enabled which removes all invalid ipv4 address from the 4 lines "Address=", "DNS=", "AllowedIPs=" and "Endpoint=". It must be set to 0 to use ipv6, eg. `WG_CONF_IPV4_ONLY=0`. You can use `WG_CONF_IPV4_LINES` to set the lines. If set to `""`, ie. `WG_CONF_IPV4_LINES=""`, no lines will be parsed.  
If you use WireGuard and also have IPv6 enabled, it is necessary to add the IPv6 range to the `LAN_NETWORK` environment variable.  

Additionally the parameter `--sysctl net.ipv6.conf.all.disable_ipv6=0` also must be added to the `docker run` command, or to the "Extra Parameters" in Unraid. The full Unraid `Extra Parameters` would be: `--restart unless-stopped --sysctl net.ipv6.conf.all.disable_ipv6=0"` If you do not do this, the container will keep on stopping with the error `RTNETLINK answers permission denied`.
Since I do not have IPv6, I did not test it.
Thanks to [mchangrh](https://github.com/mchangrh) / [Issue #49](https://github.com/DyonR/docker-qbittorrentvpn/issues/49)  

<br/><br/>

<h1 id="how_openvpn">How to use OpenVPN</h1>

The container will fail to boot if `VPN_ENABLED` is set and there is no valid .ovpn file present in the `/config/openvpn` directory. Drop a `*.ovpn` file from your VPN provider into `/config/openvpn` (if necessary with additional files like certificates) and start the container again. You may need to edit the ovpn configuration file to load your VPN credentials from a file by setting `auth-user-pass`. If you enable `OVPN_NO_CRED_FILE` along with setting `VPN_USERNAME` and `VPN_PASSWORD`, then you don't need the `credentials.conf` file. NOTE: enabling `OVPN_NO_CRED_FILE` will delete all lines matching `"auth-user-pass "` in your `*.ovpn` file.

**Note:** The script will use the first ovpn file it finds in the `/config/openvpn` directory. Adding multiple ovpn files will not start multiple VPN connections. However, the file __must be named `"default.ovpn"` to use the conf switcher feature__ enabled with `VPN_CONF_SWITCH`.

<h2 id="example_auth-user-pass">Example auth-user-pass option for .ovpn files</h2>

`auth-user-pass credentials.conf`

<h2 id="example_credentials">Example credentials.conf file, contains only 2 lines</h2>

```
rickismyusername
MySup3rS3cr3tPassword
```

<h2 id="puid_pgid">PUID/PGID</h2>

User ID (`PUID`) and Group ID (`PGID`) can be found by issuing the following command for the user you want to run the container as:

```
id <username>
```

<br/><br/>

<h2 id="notes_move_configs">Notes on MOVE_CONFIGS (default: enabled)</h2>

If `MOVE_CONFIGS` is enabled all the files in `/config/openvpn|wireguard` will be moved into the container. If `VPN_CONF_SWITCH` is enabled, so will all the files in `/config/openvpn_confs|wireguard_confs`. If any files are put back into `/config/wireguard|openvpn`, then all files inside the container will be deleted and the new ones moved in. Same for `/config/wireguard_confs|openvpn_confs`.  

<h2 id="notes_on_health_check">Notes on using the health check (default: enabled)</h2>

For every host supplied, a ping is sent to each host __per interval__. If `HEALTH_CHECK_FAILURES` is set to 3, and you have 2 hosts, then it takes 6 consecutive failed pings to trigger a restart. `HEALTH_CHECK_AMOUNT` is how many packets ping sends and `HEALTH_CHECK_PING_TIME` is how long to wait on ping to finish before timing it out. On any successful ping, the routine restarts from 0. The maximum amout of time it can take to trigger a restart is roughly `HEALTH_CHECK_FAILURES * (HEALTH_CHECK_PING_TIME * (count of HEALTH_CHECK_HOST(s)) + HEALTH_CHECK_INTERVAL)` If you cut the cable at the wall and use the defaults, then it is: `3 * (15 * 2 + 30) = 180` seconds. If `HEALTH_CHECK_PING_TIME=0`, then the timeout is disabled. If `RESTART_CONTAINER=0`, then the health check is disabled.

<h2 id="notes_up_down_scripts">Notes on VPN_DOWN_SCRIPT and VPN_UP_SCRIPT</h2>

Put `vpn_down.sh` and/or `vpn_up.sh` in the `/config` directory. You must make the scripts executable yourself, eg. `chmod +x /config/vpn_down.sh`. `/config/vpn_down.sh` runs every health check failure and `/config/vpn_up.sh` runs every health check success.

<h2 id="notes_vpn_down_file">Notes on VPN_DOWN_FILE</h2>

On health check failure, writes the file "`/config/vpn_down`" (no file extension). This can be an external way to observe the VPN state without root/sudo permission. It will be deleted after a successful connection. It contains a timestamp in the form of: `seconds_since_epoch %Y-%m-%d_%H:%M:%S.%4N` eg. 1713565909 2024-04-19_18:31:49.2800

<h2 id="notes_vpn_conf_switch">Notes on VPN_CONF_SWITCH (default: enabled)</h2>

Name your openvpn file "`default.ovpn`" (name required) or wireguard file "`wg0.conf`" (name required). For openvpn, put this 1 file in "`/config/openvpn/`", for wireguard "`/config/wireguard/`". Put all extra vpn confs in "`/config/openvpn_confs`", for wireguard "`/config/wireguard_confs`". On health check failure, a file from the `*_confs` directory is copied to `/config`. To disable, set VPN_CONF_SWITCH=0.

<h2 id="notes_dns_servers">Note on the DNS servers</h2>

https://www.how-to-hide-ip.net/no-logs-dns-server-free-public/  
FreeDNS: The servers are located in Austria, and you may use the following DNS IPs: 37.235.1.174 and 37.235.1.177.  
DNS.WATCH: The DNS servers are: 84.200.69.80 (IPv6: 2001:1608:10:25::1c04:b12f) and 84.200.70.40 (IPv6: 2001:1608:10:25::9249:d69b), located in Germany.  
1.1.1.1 and 1.0.0.1 are Cloudflare servers, they are not log free.  

<h2 id="notes_general">General notes</h2>

Docker will invoke spamming rules with `docker run` if the container restarts itself without running for at least 10 seconds. When the spamming rules are in effect, the time between restarts will keep getting longer and longer. I think it keeps doubling up the delay to some value that is extraordinarly high, it's many minutes.   

<h3 id="credits">Credits:</h3>

[MarkusMcNugen/docker-qBittorrentvpn](https://github.com/MarkusMcNugen/docker-qBittorrentvpn)  
[DyonR/jackettvpn](https://github.com/DyonR/jackettvpn)  
[coldsilk/docker-qBittorrentvpn](https://github.com/coldsilk/docker-qBittorrentvpn)  
This projects originates from MarkusMcNugen/docker-qBittorrentvpn, but forking was not possible since DyonR/jackettvpn uses the fork already.

<h3 id="qbittorrent_conf">Contents of qBittorrent.conf</h3>

```
[BitTorrent]
Session\BTProtocol=Both
Session\DefaultSavePath=/downloads
Session\TempPath=/downloads/temp
Session\TempPathEnabled=true
Session\UseRandomPort=true
Session\Port=8999
Session\DiskCacheSize=0
Session\SaveResumeDataInterval=1
Session\Interface=
Session\InterfaceName=

[Preferences]
# I'm not sure if Connection\Interface is still observed
# https://forum.qbittorrent.org/viewtopic.php?t=4532
Connection\Interface=
Connection\InterfaceName=
Connection\UPnP=false
WebUI\Username=admin
WebUI\Port=8080
WebUI\LocalHostAuth=false
WebUI\HostHeaderValidation=false
WebUI\AuthSubnetWhitelist=192.168.0.0/16, 10.0.0.0/8
WebUI\AuthSubnetWhitelistEnabled=true
WebUI\SessionTimeout=2147483647
WebUI\Password_PBKDF2="@ByteArray(gaP2miaNdYfxGkbr9JPEnA==:Wx2hp9JELBr96HKJL3gV8M36ziZirPgunx+ht7tl95Pj3QueuLKmxf2bMGjfMtkSc5wveIl5b6Hi88JvQiOPEA==)"

```
