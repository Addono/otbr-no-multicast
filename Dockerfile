FROM ubuntu:24.04

ARG GITHUB_REPO="openthread/ot-br-posix"
ARG GIT_COMMIT="main"
ARG TARGETARCH
ARG TARGETVARIANT

ENV S6_OVERLAY_VERSION=3.2.1.0

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

WORKDIR /usr/src

RUN set -x \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
           build-essential \
           ca-certificates \
           cmake \
           curl \
           git \
           ipset \
           iptables \
           ninja-build \
           wget \
           libavahi-client-dev \
           libnetfilter-queue-dev \
    \
    && case "${TARGETARCH}" in \
         "amd64") S6_ARCH="x86_64" ;; \
         "arm") S6_ARCH="arm" ;; \
         "arm64") S6_ARCH="aarch64" ;; \
         *) echo "Unsupported architecture: ${TARGETARCH}"; exit 1 ;; \
       esac \
    && curl -L -f -s "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz" \
        | tar Jxvf - -C / \
    && curl -L -f -s "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_ARCH}.tar.xz" \
        | tar Jxvf - -C / \
    \
    && git clone --depth 1 -b main https://github.com/"${GITHUB_REPO}".git \
    \
    && cd ot-br-posix \
    && git fetch origin "${GIT_COMMIT}" \
    && git checkout FETCH_HEAD \
    && git submodule update --depth 1 --init --recursive \
    \
    # Patch to disable Multicast Routing \
    && sed -i 's/"-DOPENTHREAD_CONFIG_LOG_CLI=1"/"-DOPENTHREAD_CONFIG_LOG_CLI=1" "-DOPENTHREAD_CONFIG_BACKBONE_ROUTER_MULTICAST_ROUTING_ENABLE=0"/' third_party/openthread/CMakeLists.txt \
    \
    # Version-aware build logic \
    && if grep -q "mDNSResponder" etc/docker/border-router/Dockerfile; then \
         echo "Detected legacy mDNSResponder requirement, building..." \
         && MDNS_RESPONDER_SOURCE_NAME=$(grep -oP 'MDNS_RESPONDER_SOURCE_NAME=\K[^ \s]+' etc/docker/border-router/Dockerfile || echo "mDNSResponder-2600.100.147") \
         && wget --no-check-certificate "https://github.com/apple-oss-distributions/mDNSResponder/archive/refs/tags/${MDNS_RESPONDER_SOURCE_NAME}.tar.gz" \
         && mkdir -p mDNSResponder \
         && tar xvf "${MDNS_RESPONDER_SOURCE_NAME}.tar.gz" -C mDNSResponder --strip-components=1 \
         && cd mDNSResponder/mDNSPosix \
         && make os=linux tls=no \
         && make install os=linux tls=no \
         && cd ../.. \
         && OTBR_MDNS_FLAG="-DOTBR_MDNS=mDNSResponder"; \
       else \
         echo "Using modern mDNS (openthread/avahi)..." \
         && apt-get install -y --no-install-recommends avahi-daemon \
         && OTBR_MDNS_FLAG="-DOTBR_MDNS=avahi"; \
       fi \
    \
    && cmake -GNinja \
           -DBUILD_TESTING=OFF \
           -DCMAKE_INSTALL_PREFIX=/usr \
           -DOTBR_DBUS=OFF \
           ${OTBR_MDNS_FLAG} \
           -DOTBR_REST=ON \
           -DOTBR_DUA_ROUTING=ON \
           -DOTBR_BACKBONE_ROUTER=ON \
           -DOT_BACKBONE_ROUTER=ON \
           -DOT_POSIX_NAT64_CIDR="192.168.255.0/24" \
           -DOT_FIREWALL=ON \
    && ninja \
    && ninja install \
    && cp -r etc/docker/border-router/rootfs/. / \
    && apt-get purge -y --auto-remove \
           build-essential \
           ca-certificates \
           cmake \
           curl \
           git \
           ninja-build \
           wget \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /usr/src/*

ENTRYPOINT ["/init"]
