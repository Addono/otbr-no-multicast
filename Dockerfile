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
           libavahi-client-dev \
           libnetfilter-queue-dev \
           ninja-build \
           wget \
    \
    && PLATFORM_SPEC="${TARGETARCH}${TARGETVARIANT:+/$TARGETVARIANT}" \
    && case "${PLATFORM_SPEC}" in \
         "amd64") S6_ARCH="x86_64" ;; \
         "arm/v7") S6_ARCH="arm" ;; \
         "arm64" | "arm64/v8") S6_ARCH="aarch64" ;; \
         *) echo "Unsupported architecture: ${PLATFORM_SPEC}"; exit 1 ;; \
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
    && cmake -GNinja \
           -DBUILD_TESTING=OFF \
           -DCMAKE_INSTALL_PREFIX=/usr \
           -DOTBR_DBUS=OFF \
           -DOTBR_MDNS=avahi \
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
