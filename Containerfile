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
    mkdir -p /var/home && \
    mkdir -p /var/roothome && \
    mkdir -p /var/srv && \
    mkdir -p /usr/lib/ostree && \
    mkdir /sysroot && \
    mkdir /boot && \
    ln -s /var/home /home && \
    ln -s /var/roothome /root && \
    ln -s /var/srv /srv && \
    ln -s sysroot/ostree ostree

# Clean up
RUN rm -rf /var/lib/apt && \
    rm -rf /var/cache/apt && \
    rm -rf /var/cache/debconf && \
    rm -rf /var/lib/dpkg && \
    rm -rf /var/lib/dracut && \
    rm -rf /var/lib/systemd/deb-systemd-helper-enabled && \
    rm -rf /var/lib/systemd/deb-systemd-user-helper-enabled && \
    rm -rf /var/log/apt && \
    rm -rf /var/lib/pam && \
    rm -rf /var/lib/shells.state && \
    rm -rf /var/lib/systemd/catalog && \
    rm -rf /var/log/btmp && \
    rm -rf /var/log/faillog && \
    rm -rf /var/log/syslog && \
    rm -rf /var/log/wtmp && \
    rm -rf /var/log/lastlog && \
    rm -rf /var/lib/python/python3.13_installed

# Lint
RUN bootc container lint
