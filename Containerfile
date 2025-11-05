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
    mkdir -p /var && \
    mkdir -p /var/home && \
    mkdir -p /var/roothome && \
    mkdir -p /var/srv && \
    mkdir -p /sysroot /boot && \
    mkdir -p /usr/lib/ostree && \
    ln -s /var/home /home && \
    ln -s /var/roothome /root && \
    ln -s /var/srv /srv && \
    ln -s sysroot/ostree ostree

# Lint
RUN bootc container lint
