# Build from source

The pinned base is [`fivefold3/openwrt-gl-be3600`](https://github.com/fivefold3/openwrt-gl-be3600) at the commit in [`BASE_COMMIT`](../BASE_COMMIT). The feeds are pinned in [`configs/feeds.conf`](../configs/feeds.conf). A full build needs substantial disk space, RAM, network access and time.

1. Install Docker and clone this repository. Keep the build tree outside this repository.
2. Prepare the tree and stage Wi-Fi files extracted locally from firmware for your own RD15. See [vendor-firmware.md](vendor-firmware.md).

   ```sh
   docker build -t owrt-build docker/
   scripts/prepare-tree.sh "$HOME/rd15-build"
   scripts/stage-vendor-firmware.sh --firmware /path/to/miwifi_rd15_firmware_0321a_1.0.87.bin "$HOME/rd15-build" --authorized-keys "$HOME/.ssh/id_ed25519.pub"
   ```

3. Build as the non-root user provided by the container:

   ```sh
   docker run --rm -v "$HOME/rd15-build:/b" owrt-build bash -lc 'cd /b && ./scripts/feeds update -a && ./scripts/feeds install -a && make defconfig && make -j"$(nproc)"'
   ```

   If your host UID is not 1000, adjust the container user or directory permissions first. Feed/package downloads can produce warnings for packages unrelated to this target; a nonzero build exit code still requires investigation.

4. Record SHA-256 hashes of the resulting FIT, initramfs and SquashFS before copying them to the router. Check FIT structure with `dumpimage -l`. Keep the files and their hashes together in a private directory.

`scripts/prepare-tree.sh` applies the patch to an exact base commit, then copies new files into the tree. Its `.config` is the tested *diffconfig*, not a full build cache. `make defconfig` expands it. Do not run `git add -A` inside a build tree after staging firmware or an SSH public key: both are local inputs, and built images contain proprietary firmware.

The development machine used Ubuntu 24.04 in a container and an OpenWrt SNAPSHOT based on Linux 6.18. The image is not guaranteed to be bit-for-bit reproducible; verify file hashes from each build. See [status-and-testing.md](status-and-testing.md) for the scope of validation.
