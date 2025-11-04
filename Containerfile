# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

# Base Debian Image
FROM docker.io/library/debian:stable

COPY system_files /

ENV CARGO_HOME=/tmp/rust
ENV RUSTUP_HOME=/tmp/rust
ARG DEBIAN_FRONTEND=noninteractive
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build
    
# Finalize & Lint
RUN rm -rf /boot /home /root /usr/local /srv && \
    mkdir -p /var && \
    mkdir -p /var/home && \
    mkdir -p /var/roothome && \
    mkdir -p /var/srv && \
    ln -s /var/home /home && \
    ln -s /var/roothome /root && \
    ln -s /var/srv /srv && \
    ln -s sysroot/ostree ostree && \
    mkdir -p /sysroot /boot && \
    mkdir -p /usr/lib/ostree && \
    printf "[composefs]\nenabled = yes\n[sysroot]\nreadonly = true\n" | tee "/usr/lib/ostree/prepare-root.conf" && \
    bootc container lint
