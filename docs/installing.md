# Installation on an RD15

**This is an advanced, experimental installation. There is no one-click stock-to-OpenWrt method here.** The tested route required root access to the stock firmware, a working **1.8 V** serial console and an OpenWrt initramfs booted in RAM before writing slot 0. Factory firmware commonly disables the U-Boot console interrupt (`uart_en=0`, `boot_wait=off`). This repository does not provide a method to unlock those settings on an untouched device.

## Before any write

1. Confirm the hardware is **Xiaomi BE3600 2.5G, RD15**. Other BE3600 revisions may have different flash and PHYs.
2. Isolate the LAN from your normal network. Ensure you can interrupt or recover the boot through a 1.8 V UART. Never connect a 3.3 V adapter TX to the SoC.
3. Back up *all* MTD partitions, the complete UBI volumes in both slots, the boot environment and the original FIT. Store the backups privately and check their SHA-256 hashes. In particular, preserve the device-unique `ART` and `bdata` and the intact stock slot 1. Do not upload them.
4. Build and hash the RD15 initramfs, non-initramfs FIT and `root.squashfs` as in [building.md](building.md). Inspect the FIT with `dumpimage -l`.
5. Boot the initramfs **in RAM** and verify model, Ethernet, serial, flash layout and UBI attachment before running the installer. The tested stock bootloader needed its `bootmiwifi` preamble; a direct `bootm` caused an HLOS panic even for the stock FIT. There is deliberately no generic `bootm` instruction here.

## Guarded slot-0 write

The installer is for a shell running on the RD15 **OpenWrt initramfs** with slot 0 (`rootfs`, mtd19) attached as `ubi0`. It refuses unexpected board identity, partition size, UBI volume names and image hashes. Review the script and its guards on your own unit first. The intended inputs are the locally built `xiaomi_rd15-uImage.itb` and `root.squashfs`:

```sh
sha256sum xiaomi_rd15-uImage.itb root.squashfs
# Copy both images and scripts/install-slot0.sh to /tmp on the RAM-booted router.
sh /tmp/install-slot0.sh /tmp/xiaomi_rd15-uImage.itb FIT_SHA256 /tmp/root.squashfs SQUASHFS_SHA256
```

Use the exact 64-character hashes you computed, not the placeholder words. The script writes the `kernel` and `ubi_rootfs` volumes in slot 0, reads them back and makes a `rootfs_data` UBIFS overlay. It preserves slot 1. Recreating `rootfs_data` removes existing OpenWrt settings on slot 0; restore your own backup after installation if needed. `factory.ubi` remains unqualified. Updating an existing port installation through [LuCI](upgrading.md) is a separate procedure and must not replace this initial RAM installation.

After the write, select slot 0 only if the readback succeeded and your stock fallback is verified. Observe the entire first boot on UART. Confirm `rd15-slot mark-good` has run before a cold power cycle, then check LAN, SSH, both radios and persistence. Safe image defaults leave DHCP, RA and Wi-Fi disabled after reset; provide a static management address on an isolated cable for initial configuration. The installed router in the development setup was subsequently configured as a bridge AP, not as an Internet gateway.

If any guard fails, stop and investigate the difference. Do not weaken the board, partition or volume checks to make an image flash. See [recovery-and-rollback.md](recovery-and-rollback.md).
