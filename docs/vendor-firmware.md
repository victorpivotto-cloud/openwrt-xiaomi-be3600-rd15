# Local Wi-Fi firmware staging

This repository does **not** distribute Xiaomi or Qualcomm firmware, board data, calibration or a flashable image. The build requires model-wide files from a Xiaomi **RD15** firmware image obtained by the owner of the device. The script checks file hashes against the 1.0.87 image used for the tested build. Different revisions are untested.

The staging script accepts either an original Xiaomi `HDR1` image or an already extracted root filesystem:

```sh
scripts/stage-vendor-firmware.sh --firmware /path/to/miwifi_rd15_firmware_0321a_1.0.87.bin "$HOME/rd15-build" --authorized-keys "$HOME/.ssh/id_ed25519.pub"
# or:
scripts/stage-vendor-firmware.sh --rootfs /path/to/extracted-rootfs "$HOME/rd15-build" --authorized-keys "$HOME/.ssh/id_ed25519.pub"
```

For `--firmware`, install `python3`, `squashfs-tools` (`unsquashfs`) and `ubi_reader` (`ubireader_extract_images`) on the **build host**. The script validates the RD15 marker, extracts the `root.ubi` segment and then `ubi_rootfs` into a temporary directory. It copies only the QCN6432 5 GHz user-PD/`iu_fw` pieces and board files required by the tested mix. The base tree supplies the root-PD firmware. `--allow-unverified` skips the known-hash guard and has not been validated.

The device's unique calibration and MAC addresses remain in its own `ART` partition. **Never replace or share `ART`, `bdata`, MIBIB or bootloader dumps.** Do not publish the generated tree after staging; it now contains proprietary files and possibly an SSH public key. Do not publish the resulting images.
