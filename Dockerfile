# syntax=docker/dockerfile:1.1-experimental

# SPDX-License-Identifier: Apache-2.0
#
# Copyright (c) 2023 Patrick Dung

FROM quay.io/almalinuxorg/almalinux:8 as builder

## Set desired version before building
ARG     MCROUTER_VERSION

# Docker buildx, https://docs.docker.com/build/building/multi-platform/
ARG TARGETPLATFORM

ENV     MCROUTER_DIR            /usr/local/mcrouter
ENV     INSTALL_DIR             $MCROUTER_DIR/install
ENV     SCRIPT_DIR              $MCROUTER_DIR/repo/mcrouter/mcrouter/scripts
ENV     MCROUTER_REPO           https://github.com/facebook/mcrouter.git

ENV     BOOST_VERSION="1.71.0"
ENV     FMT_VERSION="8.1.1"
ENV     SNAPPY_VERSION="1.1.9"
ENV     GFLAGS_VERSION="v2.2.2"
ENV     BISON_VERSION="v3.8.2"

RUN     --mount=type=bind,target=/tmp/scripts,source=scripts /tmp/scripts/build_deps.sh $MCROUTER_DIR
RUN     --mount=type=bind,target=/tmp/scripts,source=scripts /tmp/scripts/build.sh
RUN     cd /usr/local/mcrouter/install/bin && strip fizz fizz-bogoshim mcpiper mcrouter thrift1

FROM    quay.io/almalinuxorg/almalinux:8

ARG LABEL_IMAGE_URL
ARG LABEL_IMAGE_SOURCE

LABEL org.opencontainers.image.url=${LABEL_IMAGE_URL}
LABEL org.opencontainers.image.source=${LABEL_IMAGE_SOURCE}

ENV     MCROUTER_DIR            /usr/local/mcrouter
ENV     INSTALL_DIR             $MCROUTER_DIR/install

COPY    --from=builder /usr/local/mcrouter /usr/local/mcrouter

RUN set -eux && \
    dnf --nodocs --setopt=install_weak_deps=0 --setopt=keepcache=0 \
      -y install epel-release \
                 dnf-plugins-core \
                 https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm && \
    dnf config-manager --set-enabled powertools && \
    dnf --nodocs --setopt=install_weak_deps=0 --setopt=keepcache=0 \
      -y install \
            double-conversion-devel \
            jemalloc-devel \
            libunwind \
            pkgconf-pkg-config \
            lz4-devel \
            xz-libs \
            libevent-devel \
            snappy-devel \
            libsodium-devel \
            libicu && \
    dnf --nodocs --setopt=install_weak_deps=0 --setopt=keepcache=0 \
      -y upgrade && \
    dnf clean all && \
    rm -rf /var/cache/yum && \
    groupadd \
      --gid 20000 \
      mcrouter && \
    useradd --no-log-init \
      --create-home \
      --home-dir /home/mcrouter \
      --shell /bin/bash \
      --uid 20000 \
      --gid 20000 \
      --key MAIL_DIR=/dev/null \
      mcrouter && \
    chown -R mcrouter:mcrouter /home/mcrouter

RUN     --mount=type=bind,target=/tmp/scripts,source=scripts /tmp/scripts/runtime_deps.sh $MCROUTER_DIR

ENV     LD_LIBRARY_PATH         "$INSTALL_DIR/lib64:$INSTALL_DIR/lib:$LD_LIBRARY_PATH"

## Already added in the setup script
##ENV LD_PRELOAD=/usr/lib64/libjemalloc.so.2

USER    mcrouter
WORKDIR /home/mcrouter
