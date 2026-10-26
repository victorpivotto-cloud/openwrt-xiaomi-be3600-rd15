# Update an existing RD15 installation

The tested update path is the **LuCI firmware page**, exercised in Chrome.
Use a locally built RD15 sysupgrade from this port. This is neither a
stock-to-OpenWrt installer nor an official Attended Sysupgrade service.
Initial installation still uses the isolated [RAM/UART procedure](installing.md).

## Prepare

1. Back up the configuration, current image, UBI volumes and boot environment
   privately. Configuration backups contain Wi-Fi credentials. Keep a verified
   serial recovery path and the intact stock slot.
2. Build from the pinned base and feeds with your own vendor files and admin
   key. Keep the generated image private. BusyBox SHA1SUM is enabled because
   the existing RD15 FIT carries SHA-1 payload hashes; SHA-256 identifies the
   complete locally built artifact.
3. Inspect the image and record its SHA-256. The optional host inspector checks
   tar/FIT/layout, hashes, source parity, key permissions and selected vendor
   file parity, without writing the device:

   ```sh
   python3 scripts/check-rd15-image.py \
     --image /path/to/rd15-sysupgrade.bin \
     --fwtool /path/to/build/staging_dir/host/bin/fwtool \
     --dumpimage /path/to/build/build_dir/host/u-boot-2026.07/tools/dumpimage \
     --platform-source /path/to/build/target/linux/qualcommbe/ipq53xx/base-files/lib/upgrade/platform.sh \
     --overlay /path/to/build/files
   ```

   This is a local consistency check, not provenance authentication or a boot
   test. Source-parity checks assume the image was built from this export;
   deliberately customized defaults require reviewing the matching source.

## Install through LuCI

1. Open the configured management address in Chrome. Log in and open
   **System → Backup / Flash Firmware**.
2. Generate a configuration backup and store it privately.
3. Select **Flash image**, choose the locally built sysupgrade and upload it.
4. Compare the displayed SHA-256 with the local record. Keep **Keep settings**
   selected for an ordinary update. Stop on any validation failure; do not
   force an incompatible image.
5. Continue and leave power connected. Wait for the router to return and log
   in again. Loss of the old session during reboot is expected.
6. Verify slot success and CRC, both radios, uplink, management and actual
   client connectivity. Check that settings survived and no unintended DHCP
   or RA service started. Preserve the readback and verification results.

Chrome extension file selection may require **Allow access to file URLs**
in the extension's details. This is a browser-tool permission, not an RD15
firmware requirement; selecting a file manually also works.

## What the backend preserves

The board-specific validator checks the model, FIT configuration, hashes,
layout and capacities. The writer updates the fixed slot-0 volumes
`kernel`, `ubi_rootfs` and `rootfs_data`, with readback; it does not recreate
them using generic NAND defaults. It does not write the stock slot, ART,
bootloaders or partition table.

The safe-defaults marker lives in writable `/etc/config`, so it follows the
configuration backup. It must **never** be shipped in the immutable image.
Pre-marker installations migrate only after the existing hardening checks
pass. An update without settings or a factory reset returns to the safe
management-only defaults with Wi-Fi/DHCP/RA disabled, not the household AP
profile. Use an isolated cable and a compatible static address to recover
management after such a reset.

The generated `factory.ubi` remains unqualified. A successful update on one
unit does not establish recovery from interrupted power or every failed boot.
See [recovery and rollback](recovery-and-rollback.md).
