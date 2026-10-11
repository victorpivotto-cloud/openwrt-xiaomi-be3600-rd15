FROM ubuntu:24.04
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential clang flex bison g++ gawk gettext git libncurses-dev libssl-dev python3 \
    python3-setuptools python3-dev rsync swig unzip zlib1g-dev file wget ca-certificates curl \
    xz-utils bzip2 zstd patch perl time device-tree-compiler u-boot-tools squashfs-tools && \
    rm -rf /var/lib/apt/lists/*
RUN userdel -r ubuntu 2>/dev/null; useradd -m -u 1000 b
USER b
WORKDIR /b
