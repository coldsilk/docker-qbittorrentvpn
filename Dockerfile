FROM debian:bookworm-slim

WORKDIR /opt

RUN `# Install prerequisites` \
    apt update \
    && apt upgrade -y \
    && apt install -y --no-install-recommends \
    curl \
    ca-certificates \
    jq \
    unzip

RUN `# Install Boost` \
    apt install -y --no-install-recommends \
    g++ \
    libxml2-utils \
    && BOOST_VERSION_DOT=$(curl -sX GET "https://www.boost.org/feed/news.rss" | xmllint --xpath '//rss/channel/item/title/text()' - | awk -F 'Version' '{print $2 FS}' - | sed -e 's/Version//g;s/\ //g' | xargs | awk 'NR==1{print $1}' -) \
    && BOOST_VERSION=$(echo ${BOOST_VERSION_DOT} | head -n 1 | sed -e 's/\./_/g') \
    && curl -o /opt/boost_${BOOST_VERSION}.tar.gz -L https://boostorg.jfrog.io/artifactory/main/release/${BOOST_VERSION_DOT}/source/boost_${BOOST_VERSION}.tar.gz \
    && tar -xzf /opt/boost_${BOOST_VERSION}.tar.gz -C /opt \
    && cd /opt/boost_${BOOST_VERSION} \
    && ./bootstrap.sh --prefix=/usr \
    && ./b2 --prefix=/usr install \
    && cd /opt \
    && rm -rf /opt/* \
    && apt -y purge \
    g++ \
    libxml2-utils \
    && apt-get clean \
    && apt --purge autoremove -y

RUN `# Install Ninja` \
    # hard linked URL since Ninja v1.12.0 seemingly broke something
    && NINJA_DOWNLOAD_URL=https://github.com/ninja-build/ninja/releases/download/v1.11.1/ninja-linux.zip \
    # && NINJA_ASSETS=$(curl -sX GET "https://api.github.com/repos/ninja-build/ninja/releases" | jq '.[] | select(.prerelease==false) | .assets_url' | head -n 1 | tr -d '"')
    # && NINJA_DOWNLOAD_URL=$(curl -sX GET ${NINJA_ASSETS} | jq '.[] | select(.name | match("ninja-linux";"i")) .browser_download_url' | tr -d '"')
    && curl -o /opt/ninja-linux.zip -L ${NINJA_DOWNLOAD_URL} \
    && unzip /opt/ninja-linux.zip -d /opt \
    && mv /opt/ninja /usr/local/bin/ninja \
    && chmod +x /usr/local/bin/ninja \
    && rm -rf /opt/*

RUN `# Install CMake` \
    && CMAKE_ASSETS=$(curl -sX GET "https://api.github.com/repos/Kitware/CMake/releases" | jq '.[] | select(.prerelease==false) | .assets_url' | head -n 1 | tr -d '"') \
    && CMAKE_DOWNLOAD_URL=$(curl -sX GET ${CMAKE_ASSETS} | jq '.[] | select(.name | match("Linux-x86_64.sh";"i")) .browser_download_url' | tr -d '"') \
    && curl -o /opt/cmake.sh -L ${CMAKE_DOWNLOAD_URL} \
    && chmod +x /opt/cmake.sh \
    && /bin/bash /opt/cmake.sh --skip-license --prefix=/usr \
    && rm -rf /opt/*

RUN `# Install libtorrent` \
    apt install -y --no-install-recommends \
    build-essential \
    libssl-dev \
    && LIBTORRENT_ASSETS=$(curl -sX GET "https://api.github.com/repos/arvidn/libtorrent/releases" | jq '.[] | select(.prerelease==false) | select(.target_commitish=="RC_1_2") | .assets_url' | head -n 1 | tr -d '"') \
    && LIBTORRENT_DOWNLOAD_URL=$(curl -sX GET ${LIBTORRENT_ASSETS} | jq '.[0] .browser_download_url' | tr -d '"') \
    && LIBTORRENT_NAME=$(curl -sX GET ${LIBTORRENT_ASSETS} | jq '.[0] .name' | tr -d '"') \
    && curl -o /opt/${LIBTORRENT_NAME} -L ${LIBTORRENT_DOWNLOAD_URL} \
    && tar -xzf /opt/${LIBTORRENT_NAME} \
    && rm /opt/${LIBTORRENT_NAME} \
    && cd /opt/libtorrent-rasterbar* \
    && cmake -G Ninja -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX:PATH=/usr -DCMAKE_CXX_STANDARD=17 \
    && cmake --build build --parallel $(nproc) \
    && cmake --install build \
    && cd /opt \
    && rm -rf /opt/* \
    && apt purge -y \
    build-essential \
    libssl-dev \
    && apt-get clean \
    && apt --purge autoremove -y

RUN `# Compile and install qBittorrent` \
    apt install -y --no-install-recommends \
    build-essential \
    git \
    libssl-dev \
    pkg-config \
    qtbase5-dev \
    qttools5-dev \
    qtbase5-private-dev \
    zlib1g-dev \
    && QBITTORRENT_RELEASE=$(curl -sX GET "https://api.github.com/repos/qBittorrent/qBittorrent/tags" | jq '.[] | select(.name | index ("alpha") | not) | select(.name | index ("beta") | not) | select(.name | index ("rc") | not) | .name' | head -n 1 | tr -d '"') \
    && curl -o /opt/qBittorrent-${QBITTORRENT_RELEASE}.tar.gz -L "https://github.com/qbittorrent/qBittorrent/archive/${QBITTORRENT_RELEASE}.tar.gz" \
    && tar -xzf /opt/qBittorrent-${QBITTORRENT_RELEASE}.tar.gz \
    && rm /opt/qBittorrent-${QBITTORRENT_RELEASE}.tar.gz \
    && cd /opt/qBittorrent-${QBITTORRENT_RELEASE} \
    && cmake -G Ninja -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local -DGUI=OFF -DCMAKE_CXX_STANDARD=17 \
    && cmake --build build --parallel $(nproc) \
    && cmake --install build \
    && cd /opt \
    && rm -rf /opt/* \
    && apt purge -y \
    build-essential \
    git \
    libssl-dev \
    pkg-config \
    qtbase5-dev \
    qttools5-dev \
    qtbase5-private-dev \
    zlib1g-dev \
    && apt-get clean \
    && apt --purge autoremove -y

# Install WireGuard and some other dependencies some of the scripts in the container rely on.
RUN `# Install WireGuard, OpenVPN and other tools` \
    && echo "deb http://deb.debian.org/debian/ bookworm non-free" > /etc/apt/sources.list \
    && printf 'Package: *\nPin: release a=non-free\nPin-Priority: 150\n' > /etc/apt/preferences.d/limit-non-free \
    && apt update \
    && apt install -y --no-install-recommends \
    iproute2 \
    dos2unix \
    python3 \
    tzdata \
    wireguard-tools \
    openresolv \
    openvpn \
    inetutils-ping \
    ipcalc \
    iptables \
    kmod \
    libqt5network5 \
    libqt5xml5 \
    libqt5sql5 \
    libssl3 \
    moreutils \
    net-tools \
    procps \
    wget \
    netcat-openbsd \
    nano \
    p7zip-full \
    zip \
    unrar \
    xz-utils \
    gzip \
    && apt-get clean \
    && apt --purge autoremove -y

RUN `# Install newer version of ipcalc` \
    apt install -y --no-install-recommends \
    build-essential \
    && curl -o /opt/ipcalc-1.0.3.tar.gz -L https://gitlab.com/ipcalc/ipcalc/-/archive/1.0.3/ipcalc-1.0.3.tar.gz \
    && tar -xzf /opt/ipcalc-1.0.3.tar.gz -C /opt \
    && cd /opt/ipcalc-1.0.3 \
    && make USE_GEOIP=no USE_MAXMIND=no \
    && cp -f ipcalc /usr/local/bin/ipcalc \
    && rm -rf /opt/* \
    && apt purge -y \
    build-essential

# Clean up
RUN `# Clean up` \
    apt-get clean \
    && apt --purge autoremove -y \
    && rm -rf \
    /usr/local/bin/ninja \
    /var/lib/apt/lists/* \
    /tmp/* \
    /var/tmp/*

# Remove src_valid_mark from wg-quick
RUN `# Patch wg-quick` \
    sed -i /net\.ipv4\.conf\.all\.src_valid_mark/d `which wg-quick`

# Create volumes
VOLUME /config /downloads

# Make directories
RUN `# Make directories` \
    mkdir -p \
    /config/qBittorrent \
    /downloads \
    /vpn_files/openvpn/ \
    /vpn_files/wireguard/

ADD qbittorrent/ /etc/qbittorrent/
ADD scripts/ /scripts/

# Add files
ADD README.md /scripts/
ADD speedtest /usr/bin
ADD bashrc /root/.bashrc
ADD . /_app_src

# Permisssions
RUN `# Set executable permissions` \
    chmod +x \
    /etc/qbittorrent/*.bash \
    /scripts/*.bash \
    /usr/bin/speedtest

# Suggested default Web UI port (EXPOSE doesn't actually expose a port)
EXPOSE 8080
# Suggested default torrenting port
EXPOSE 8999
EXPOSE 8999/udp

WORKDIR /root

ENTRYPOINT ["/bin/bash", "/etc/qbittorrent/start.bash"]

