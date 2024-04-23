# [qBittorrent](https://github.com/qbittorrent/qBittorrent), [WireGuard](https://www.wireguard.com/) and [OpenVPN](https://openvpn.net)
[![Docker Pulls](https://img.shields.io/docker/pulls/coldsilk/docker-qbittorrent)](https://hub.docker.com/r/coldsilk/docker-qbittorrent)
[![Docker Image Size (tag)](https://img.shields.io/docker/image-size/coldsilk/docker-qbittorrent/latest)](https://hub.docker.com/r/coldsilk/docker-qbittorrent)

<h2 id="version">Version 1.2.2 (2024-04-20)</h2>

Docker container which runs the latest [qBittorrent](https://github.com/qbittorrent/qBittorrent)-nox client while connecting to WireGuard or OpenVPN with iptables killswitch to prevent IP leakage when the tunnel goes down with an automatic VPN conf switcher incase you have a free/unstable VPN.

<h2 id="coldsilk_added_features">Things added on coldsilk fork</h2>

* Option of a VPN conf switcher incase you have a free/unstable VPN [(read notes)](#notes_vpn_conf_switch)
* Shutdown of qBittorrent with cURL to save downloaded torrent data. This is also apparently important for trackers that you want to collect your usage such as quota based private trackers [(read notes)](#notes_shutdown)
* Option to set the "Network Interface:" inside qBittorrent to the VPN adapter, ie. wg0 or tun0 or tap0
* Option to use OpenVPN without having a "userpass.txt" file [(read notes)](#how_openvpn)
* Option to change qBittorrent's Web UI port and Torrenting port
* Health check can now go N ping failures to N servers before restarting [(read notes)](#notes_on_health_check)
* Default username and password is back to admin/adminadmin
* Option to auto-strip ipv6 addresses in wg0.conf [(read notes)](#how_wireguard)
* Option to write a file to /config while the internet is seemingly down [(read notes)](#notes_vpn_down_file)  
* Option to run a script when the health check succeeds and/or fails [(read notes)](#notes_up_down_scripts)  
* Added a simple .bash script to send .torrents and magnets (it's copied to /config)
* Added a reaper to restart the container if not connected by N seconds (default: 30).
* Option to move the VPN config files into the container [(read notes)](#notes_move_configs)  
* Option to pass VPN options to OpenVPN
* Option to set timezone
* Can now also use *.conf files for OpenVPN (prior it was just *.ovpn files)
  
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

The container is available from the Docker registry. To run the container use the below command. For additional parameters, please [read below](#variables_volumes_ports).

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

| Variable | Function | Example 
|----------|----------|----------|
|`VPN_ENABLED` | Enable VPN? | `VPN_ENABLED=1`
|`VPN_TYPE` | WireGuard or OpenVPN (wireguard/openvpn)? | `VPN_TYPE=openvpn`
|`REAP_WAIT` | Restart if not connected by N seconds. VPN_CONF_SWITCH is observed. | `REAP_WAIT=30`
|`VPN_CONF_SWITCH` | On health check or startup failures, switch conf/ovpn file. [(read notes)](#notes_vpn_conf_switch) | `VPN_CONF_SWITCH=1`
|`MOVE_CONFIGS` | Move VPN config files into the container. | `MOVE_CONFIGS=0`
|`QBT_WEBUI_PORT` | Sets the WebUI port for qBittorrent. | `QBT_WEBUI_PORT=8080`
|`QBT_TORRENTING_PORT` | Sets the torrent port for qBittorrent. | `QBT_TORRENTING_PORT=8999`
|`SHUTDOWN_WAIT` | On health check failure restarts, seconds to wait for qBittorent to shutdown before force killing. | `SHUTDOWN_WAIT=30`
|`TZ` | Timezone. Choose from column "TZ identifier" here [List of tz database time zones](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones#List). | `TZ=Etc/UTC`
|`VPN_USERNAME` | If username and password are set, configures ovpn file automatically. | `VPN_USERNAME=(empty)`
|`VPN_PASSWORD` | If username and password are set, configures ovpn file automatically. | `VPN_PASSWORD=(empty)`
|`VPN_OPTIONS` | Options for OpenVPN (whitespace is not filtered). | `VPN_OPTIONS=(empty)`
|`_QBT_USERNAME` | Read [notes on SHUTDOWN_WAIT](#notes_shutdown). | `_QBT_USERNAME=admin`
|`_QBT_PASSWORD` | Read [notes on SHUTDOWN_WAIT](#notes_shutdown). | `_QBT_PASSWORD=adminadmin`
|`QBT_SET_INTERFACE` | Sets the "Network Inerface:" in qBittorrent to wg0, tun0 or tap0. | `QBT_SET_INTERFACE=1`
|`OVPN_NO_CRED_FILE` | Do not use userpass.txt file with OpenVPN; deletes all "auth-user-pass" lines from conf/ovpn files. | `OVPN_NO_CRED_FILE=0`
|`WG_CONF_IPV4_ONLY` | Remove all invalid ipv4 addresses from the lines defined by WG_CONF_IPV4_LINES in "wg0.conf". | `WG_CONF_IPV4_ONLY=1`
|`WG_CONF_IPV4_LINES` | Line starting words to parse for removing invalid ipv4 addresses in "wg0.conf". | `WG_CONF_IPV4_LINES="Address, DNS, AllowedIPs, Endpoint"`
|`LAN_NETWORK` | Local Network's with CIDR notation. Comma delimited. | `LAN_NETWORK="192.168.0.0/16, 10.0.0.0/8"`
|`LEGACY_IPTABLES` | Use iptables (legacy) instead of iptables (nf_tables). | `LEGACY_IPTABLES=0`
|`ENABLE_SSL` | Let the container configure SSL in "qBittorrent.conf". If enabled, files in /config need to be named "WebUICertificate.crt" and "WebUIKey.key" | `ENABLE_SSL=0`
|`NAME_SERVERS` | Name servers. Comma delimited. [(read notes)](#notes_dns_servers) | `NAME_SERVERS="1.1.1.1, 37.235.1.174, 84.200.69.80, 84.200.70.40, 1.0.0.1, 37.235.1.177"`
|`PUID` | UID applied to /config files and /downloads. | `PUID="1000"`
|`PGID` | GID applied to /config files and /downloads. | `PGID="1000"`
|`UMASK` | |`UMASK="002"`
|`HEALTH_CHECK_HOSTS` | Hosts used to check for an active internet connection. Comma delimited. [(read notes)](#notes_on_health_check) | `HEALTH_CHECK_HOSTS="1.1.1.1, 84.200.69.80"`
|`HEALTH_CHECK_INTERVAL` | Time in seconds that the container waits to see if the internet connection has died. [(read notes)](#notes_on_health_check) | `HEALTH_CHECK_INTERVAL=29`
| `HEALTH_CHECK_FAILURES` | The amount of intervals that have to fail before a restart can happen. [(read notes)](#notes_on_health_check) | `HEALTH_CHECK_FAILURES=3`
|`HEALTH_CHECK_AMOUNT` | The amount of packets ping sends. [(read notes)](#notes_on_health_check) | `HEALTH_CHECK_AMOUNT=3`
|`HEALTH_CHECK_PING_TIME` | Timeout ping after N seconds. [(read notes)](#notes_on_health_check) | `HEALTH_CHECK_PING_TIME=14`
|`HEALTH_CHECK_SILENT` | Set to 1 to supress the 'Network is up' message. | `HEALTH_CHECK_SILENT=1`
|`RESTART_CONTAINER` | Set to 0 to **disable** the automatic restart when the network is possibly down. | `RESTART_CONTAINER=1`
|`ADDITIONAL_PORTS` | List to allow via iptables. Comma delimited. | `ADDITIONAL_PORTS=(empty)`
|`VPN_DOWN_FILE` | On health check failure, appends to "/config/vpn_down" file. [(read notes)](#notes_vpn_down_file) | `VPN_DOWN_FILE=2`
|`VPN_DOWN_SCRIPT` | On health check failure, run "/config/vpn_down.sh". | `VPN_DOWN_SCRIPT=0`
|`VPN_UP_SCRIPT` | On health check success, run "/confing/vpn_up.sh". | `VPN_UP_SCRIPT=0`

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

<h3 id="web_ui_login">Default Web UI login:</h3>

username: `admin`  
password: `adminadmin`  

<br/><br/>

<h1 id="notes_shutdown">Notes on SHUTDOWN_WAIT</h1>

<h3 id="curl_shutdown">Using `curl` to shutdown qbittorrent-nox.</h3>

__Requires__: 
1. "Bypass authentication for clients on localhost" (under the "Web UI" tab)
2. or "Bypass authentication for clients in whitelisted IP subnets" (under the "Web UI" tab)
3. or Setting `_QBT_USERNAME` and `_QBT_PASSWORD`. 

By default, local host access is enabled in the qBittorrent.conf file with the line `WebUI\LocalHostAuth=false` and whitelisted IPs are enabled by the line `WebUI\AuthSubnetWhitelist=192.168.0.0/16, 10.0.0.0/8`.   
If the `curl` command fails the request, SIGABRT is used.
If `SHUTDOWN_WAIT` is reached, the script force kills and exits with code 99.   
Internally, cURL shut downs happen on health check failures or by sending SIGABRT to process 1 in the container.  
Externally, restart the container with `docker restart` with the signal and a long enough timeout, ie __`docker restart -s SIGABRT -t 180 qbittorrent`__  
To stop the container, use `docker stop` the same way, ie. __`docker stop -s SIGABRT -t 180 qbittorrent`__  
Utimately, if the trap is triggered, 2 or 3 cURL related commands happen.
1. `curl -v -d "username=$_QBT_USERNAME&password=$_QBT_PASSWORD" -X POST 127.0.0.1:$QBT_WEBUI_PORT/api/v2/auth/login"`
2. `curl -v -H "Cookie: SID=$sid" -X POST 127.0.0.1:$QBT_WEBUI_PORT/api/v2/app/shutdown`
3. `curl -v -d "" 127.0.0.1:$QBT_WEBUI_PORT/api/v2/app/shutdown`  

Command 1. gets the SID string, 2. tries to shut down using POST, 3. only happens if 2. fails and solely exists in case the SID doesn't parse but, you need 1 of the bypassing authentication options set for 3. to work (notice no username/password).  
If the curl command succeeds, then it waits on the process to exit or until `SHUTDOWN_WAIT` is reached.  
If the curl command fails, SIGABRT is sent immediately and waits on the process to exit or until `SHUTDOWN_WAIT` is reached.  
Some trackers will want to collect data usage, so if you care about that because you use private trackers or something else, set the value for `SHUTDOWN_WAIT` pretty high. Most of the time during a shutdown will be allocated to disconnecting, not saving the torrent data, which happens quickly.   
Reference: https://docs.docker.com/reference/cli/docker/container/stop/

<br/><br/>

<h1 id="how_wireguard">How to use WireGuard</h1>

The container will fail to boot if `VPN_ENABLED` is set and there is no valid .conf file present in the /config/wireguard directory. The file must have the name `wg0.conf`, or it will fail to start.

<h2 id="wireguard_ipv6">WireGuard IPv6 issues</h2>

By default, `WG_CONF_IPV4_ONLY` is enabled which removes all invalid ipv4 addresses from the 4 lines "Address=", "DNS=", "AllowedIPs=" and "Endpoint=". It must be set to 0 to use ipv6, eg. `WG_CONF_IPV4_ONLY=0`. You can use `WG_CONF_IPV4_LINES` to set the lines. If set to `""`, ie. `WG_CONF_IPV4_LINES=""`, no lines will be parsed.  
If you use WireGuard and also have IPv6 enabled, it is necessary to add the IPv6 range to the `LAN_NETWORK` environment variable.  

Additionally the parameter `--sysctl net.ipv6.conf.all.disable_ipv6=0` also must be added to the `docker run` command, or to the "Extra Parameters" in Unraid. The full Unraid `Extra Parameters` would be: `--restart unless-stopped --sysctl net.ipv6.conf.all.disable_ipv6=0"` If you do not do this, the container will keep on stopping with the error `RTNETLINK answers permission denied`.
Since I do not have IPv6, I did not test it.
Thanks to [mchangrh](https://github.com/mchangrh) / [Issue #49](https://github.com/DyonR/docker-qbittorrentvpn/issues/49)  

<br/><br/>

<h1 id="how_openvpn">How to use OpenVPN</h1>

The container will fail to boot if `VPN_ENABLED` is `1` and there is no valid `*.conf` or `*.ovpn` file present in the `/config/openvpn` directory. Put a `*.conf` or `*.ovpn` file into `/config/openvpn` and if necessary, any additional files like certificates, userpass, etc. then restart the container. You may need to edit the configuration file to load your VPN credentials from a file by setting `auth-user-pass` (example below). If you enable `OVPN_NO_CRED_FILE` along with setting both `VPN_USERNAME` and `VPN_PASSWORD`, then you don't need the `userpass.txt` file. NOTE: enabling `OVPN_NO_CRED_FILE` will delete all lines matching `"auth-user-pass "` in your `*.conf/*.ovpn` file.

**Note:** The script will first look for a file named `default.ovpn`. If it fails to find that, then the script will use the first `*.conf` or `*.ovpn` file it finds in the `/config/openvpn` directory that is not named `credentials.conf` or has the text `*userpass*` in its file name.

<h2 id="example_auth-user-pass">Example auth-user-pass option inside of *.conf/*.ovpn files</h2>

`auth-user-pass userpass.txt`

<h2 id="example_credentials">Example userpass.txt file, contains only 2 lines</h2>

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

<h2 id="notes_move_configs">Notes on MOVE_CONFIGS</h2>

If `MOVE_CONFIGS` is enabled, all the files in `/config/openvpn|wireguard` will be moved into the container and if `VPN_CONF_SWITCH` is enabled, so will all the files in `/config/openvpn_confs|wireguard_confs`. If any files are put back into `/config/wireguard|openvpn` or `/config/wireguard_confs|openvpn_confs`, then all respective files inside the container will be deleted and the new ones moved in.

<h2 id="notes_on_health_check">Notes on using the health check (default: enabled)</h2>

For every host supplied, a ping is sent to each host __per interval__. If `HEALTH_CHECK_FAILURES` is set to 3, and you have 2 hosts, then it takes 6 consecutive failed pings to trigger a restart. `HEALTH_CHECK_AMOUNT` is how many packets ping sends and `HEALTH_CHECK_PING_TIME` is how long to wait on ping to finish before timing it out. On any successful ping, the routine restarts from 0. The maximum amout of time it can take to trigger a restart is roughly `HEALTH_CHECK_FAILURES * (HEALTH_CHECK_PING_TIME * (count of HEALTH_CHECK_HOSTS) + HEALTH_CHECK_INTERVAL)` If you cut the cable at the wall and use the defaults, then the maximum time is: `3 * (14 * 2 + 29) = 171` seconds. If `HEALTH_CHECK_PING_TIME=0`, then the timeout on ping is disabled. If `RESTART_CONTAINER=0`, then the entire health check is disabled.

<h2 id="notes_up_down_scripts">Notes on VPN_DOWN_SCRIPT and VPN_UP_SCRIPT</h2>

Put `vpn_down.sh` and/or `vpn_up.sh` in the `/config` directory. You must make the scripts executable yourself, eg. `chmod +x /config/vpn_down.sh`. `/config/vpn_down.sh` runs every health check failure and `/config/vpn_up.sh` runs every health check success.

<h2 id="notes_vpn_down_file">Notes on VPN_DOWN_FILE (default: enabled)</h2>

On health check failures that cause a restart, it writes the file `/config/vpn_down` (no file extension). If set to 1, the file will be deleted after the first successful health check. If set to 2, the file won't be deleted. This can be an external way to observe the VPN state without root/sudo permission. I use it to know when to restart other containers that I have proxied to this one. The file contains a timestamp in the form of: `seconds_since_epoch %Y-%m-%d_%H:%M:%S.%4N` eg. 1713565909 2024-04-19_18:31:49.2800 The write mode is append so it can also be used as a log to know how many times and when the container has restarted from health check failures.

<h2 id="notes_vpn_conf_switch">Notes on VPN_CONF_SWITCH (default: enabled)</h2>

Put your *.ovpn file or wg0.conf in `/config/openvpn` or `/config/wireguard` respectively. Put all openvpn confs in `/config/openvpn_confs` or `/config/wireguard_confs` respectively. On health check failure restarts, a file from the `*_confs` directory is copied to `/config`. To disable, set VPN_CONF_SWITCH=0.

<h2 id="notes_dns_servers">Note on the DNS servers</h2>

https://www.how-to-hide-ip.net/no-logs-dns-server-free-public/  
FreeDNS: The servers are located in Austria, and you may use the following DNS IPs: 37.235.1.174 and 37.235.1.177.  
DNS.WATCH: The DNS servers are: 84.200.69.80 (IPv6: 2001:1608:10:25::1c04:b12f) and 84.200.70.40 (IPv6: 2001:1608:10:25::9249:d69b), located in Germany.  
1.1.1.1 and 1.0.0.1 are Cloudflare servers, they are not log free.  

<h2 id="notes_general">General notes</h2>

Docker will invoke spamming rules with `docker run` if the container restarts itself without running for at least 10 seconds. When the spamming rules are in effect, the time between restarts will keep getting longer and longer. I think it keeps doubling up the delay to some value that is extraordinarly high, it's many minutes. This container will typically dodge that with the exception of if a `iptables` command fails.   

<h3 id="credits">Credits</h3>

[MarkusMcNugen/docker-qBittorrentvpn](https://github.com/MarkusMcNugen/docker-qBittorrentvpn)  
[DyonR](https://github.com/DyonR)  
[binhex](https://github.com/binhex/) who I have a feeling wrote most of the original scripts but, wasn't credited prior :-/   
[coldsilk/docker-qBittorrentvpn](https://github.com/coldsilk/docker-qBittorrentvpn)  

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
