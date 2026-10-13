# Recovery and rollback

Keep a verified 1.8 V UART and private flash backups until several cold boots have passed. The fallback relies on the second Xiaomi slot remaining intact; a factory reset is not a flash backup.

The tested unit subsequently passed three cold boots without serial input.
If the owner removes the UART wiring to close the case, software recovery
through SSH remains possible only while OpenWrt boots and the LAN is
reachable. Serial/U-Boot recovery will require reopening the case and
reconnecting a 1.8 V adapter. Image upgrades through LuCI/sysupgrade are
still unsupported on this port; a configuration backup is not a firmware
image or a flash backup.

## OpenWrt is reachable

`rd15-slot boot-stock` selects the Xiaomi slot and reboots. Run it only while the RD15 is isolated: stock Xiaomi firmware may start its own DHCP service. Check UART for `os_idx = 1` and `ubi.mtd=rootfs_1`, then verify the stock web interface. Do not erase slot 0 to perform this rollback.

On the tested stock firmware, selecting the OpenWrt slot again with Xiaomi's `nvram` flags worked, but command names and flag behavior can vary across versions. Verify the environment and a recovery path on your unit before changing flags. Repeated failed boots can also trigger stock U-Boot's slot fallback automatically; do not count on the exact attempt threshold.

## OpenWrt is unreachable

Use the serial console to inspect the bootloader's slot selection and boot messages. If you have an intact slot 1, select it using the stock U-Boot's environment only after verifying the current flags and their meaning. Save no permanent change to bootloader variables until you know how to reverse it. A serial console is 1.8 V; keep VCC disconnected.

If both slots are damaged, restoration requires **your own** verified backups and board-specific flash access. This repository does not contain Xiaomi images, ART, bdata or a whole-flash image. Never write another unit's `ART`, `bdata`, MIBIB or APPSBL. The public scripts intentionally have no command that writes those partitions.

The tested unit's original slot-0 FIT was privately backed up before development. A later no-`pause` FIT was rebuilt as an approximate rollback artifact, but it was **not** tested on the device and is not included here. Preserve your own known-good image instead.
