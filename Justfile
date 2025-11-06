set dotenv-load := true

image_name := env("BUILD_IMAGE_NAME", "debian-bootc-core")
image_repo := env("BUILD_IMAGE_REPO", "ghcr.io/linuxsnow")
image_tag := env("BUILD_IMAGE_TAG", "latest")
base_dir := env("BUILD_BASE_DIR", ".")
filesystem := env("BUILD_FILESYSTEM", "ext4")
selinux := path_exists('/sys/fs/selinux')

default:
    just --list --unsorted

build-container $image_name=image_name:
    sudo podman build -t "{{ image_name }}:{{ image_tag }}" .

run-container $image_name=image_name:
    sudo podman run --rm -it "{{ image_name }}:{{ image_tag }}" bash

bootc *ARGS:
    sudo podman run \
        --rm --privileged --pid=host \
        -it \
        -v /etc/containers:/etc/containers{{ if selinux == 'true' { ':Z' } else { '' } }} \
        -v /var/lib/containers:/var/lib/containers{{ if selinux == 'true' { ':Z' } else { '' } }} \
        {{ if selinux == 'true' { '-v /sys/fs/selinux:/sys/fs/selinux' } else { '' } }} \
        {{ if selinux == 'true' { '--security-opt label=type:unconfined_t' } else { '' } }} \
        -v /dev:/dev \
        -e RUST_LOG=debug \
        -v "{{ base_dir }}:/data" \
        "{{ image_name }}:{{ image_tag }}" bootc {{ ARGS }}

# accelerate bootc image building with /tmp
setup-bootc-accelerator:
    echo "BUILD_BASE_DIR=/tmp" > .env

generate-bootable-image $base_dir=base_dir $filesystem=filesystem:
    #!/usr/bin/env bash
    image_filename={{ image_name }}.img
    if [ ! -e "{{ base_dir }}/${image_filename}" ] ; then
        fallocate -l 20G "{{ base_dir }}/${image_filename}"
    fi
    just bootc install to-disk \
            --composefs-backend \
            --via-loopback /data/${image_filename} \
            --filesystem "{{ filesystem }}" \
            --target-imgref {{ image_repo }}/{{ image_name }}:{{ image_tag }} \
            --wipe \
            --bootloader systemd

launch-incus:
    #!/usr/bin/env bash
    image_file={{ base_dir }}/{{ image_name }}.img

    if [ ! -f "$image_file" ]; then
        echo "No image file found, generate-bootable-image first"
        exit 1
    fi

    abs_image_file=$(realpath "$image_file")

    instance_name="{{ image_name }}"
    echo "Creating instance $instance_name from image file $abs_image_file"
    incus init "$instance_name" --empty --vm

    incus config set "$instance_name" limits.cpu=4 limits.memory=8GiB
    incus config set "$instance_name" security.secureboot=false
    incus config device add "$instance_name" vtpm tpm
    incus config device add "$instance_name" install disk source="$abs_image_file" boot.priority=90
    incus start "$instance_name"


    echo "$instance_name is Starting..."

    incus console --type=vga "$instance_name"

rm-incus:
    #!/usr/bin/env bash
    instance_name="{{ image_name }}"
    echo "Stopping and removing instance $instance_name"
    incus rm --force "$instance_name" || true
