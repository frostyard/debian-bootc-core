image_name := env("BUILD_IMAGE_NAME", "snow-base")
image_tag := env("BUILD_IMAGE_TAG", "latest")
base_dir := env("BUILD_BASE_DIR", "/tmp")
filesystem := env("BUILD_FILESYSTEM", "ext4")

build-containerfile $image_name=image_name:
    sudo podman build --no-cache -t "${image_name}:latest" .

bootc *ARGS:
    sudo podman run \
        --rm --privileged --pid=host \
        -it \
        -v /etc/containers:/etc/containers:Z \
        -v /var/lib/containers:/var/lib/containers:Z \
        -v /dev:/dev \
        -e RUST_LOG=debug \
        -v "{{base_dir}}:/data" \
        --security-opt label=type:unconfined_t \
        "{{image_name}}:{{image_tag}}" bootc {{ARGS}}

generate-bootable-image $base_dir=base_dir $filesystem=filesystem:
    #!/usr/bin/env bash
    if [ ! -e "${base_dir}/snowbase.img" ] ; then
        fallocate -l 20G "${base_dir}/snowbase.img"
    fi
    just bootc install to-disk --composefs-backend --via-loopback /data/snowbase.img --filesystem "${filesystem}" --wipe --bootloader systemd

launch-incus:
    #!/usr/bin/env bash
    image_file=/tmp/snowbase.img

    if [ -z "$image_file" ]; then
        echo "No image file found, generate-bootable-image first"
        exit 1
    fi

    abs_image_file=$(realpath "$image_file")

    # make the instance_name "snow" plus the variant
    instance_name="snow-base"
    echo "Creating instance $instance_name from image file $abs_image_file"
    incus init "$instance_name" --empty --vm

    incus config set "$instance_name" limits.cpu=4 limits.memory=8GiB
    incus config set "$instance_name" security.secureboot=false
    incus config device add "$instance_name" vtpm tpm
    incus config device add "$instance_name" install disk source="$abs_image_file" boot.priority=90
    incus start "$instance_name"


    echo "snow-base is Starting..."

    incus console --type=vga "$instance_name"

rm-incus:
    #!/usr/bin/env bash
    instance_name="snow-base"
    echo "Stopping and removing instance $instance_name"
    incus rm --force "$instance_name" || true

