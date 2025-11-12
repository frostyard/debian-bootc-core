# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

# Base Debian Image
FROM docker.io/library/debian:stable

COPY system_files /

ARG DEBIAN_FRONTEND=noninteractive
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/install-bootc && \
    /ctx/build && \
    rm -rf \
        /boot \
        /home \
        /root \
        /srv && \
    mkdir /sysroot && \
    mkdir /boot && \
    mkdir /root && \
    mkdir /home && \
    mkdir /srv && \
    ln -s sysroot/ostree ostree

# DEBUGGING
# RUN apt update -y && apt install -y whois
# RUN usermod -p "$(echo "changeme" | mkpasswd -s)" root

# Lint
RUN bootc container lint
