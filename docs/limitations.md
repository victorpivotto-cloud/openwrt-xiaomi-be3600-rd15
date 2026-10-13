# Limitations and safety boundary

This is an experimental port tested on one Xiaomi BE3600 2.5G **RD15**. It is not an official OpenWrt target or a universal BE3600 image. Check the hardware ID before using any part of the installation procedure.

- The **installed** image does not enable the 2.5 GbE port: its DTS omits PPE port 1 and its kernel has `CONFIG_MOTORCOMM_PHY` disabled. A separate RAM-only branch bound this unit's YT8821 at MDIO `0x07`, negotiated both 2.5 and 1 Gb/s, and reached 2.35 Gb/s in a short local TCP test. That branch has not been installed or qualified for sustained traffic; its 2.5 GbE USB test partner failed during a longer run. The three 1 GbE LAN ports work in the installed image.
- `sysupgrade` and `factory.ubi` are not supported installation paths. The installed `platform.sh` rejects `xiaomi,rd15`, and generic NAND upgrade handling does not match this device's `kernel`/`ubi_rootfs`/`rootfs_data` layout. Use the guarded slot-0 procedure only after a RAM boot, complete backups and a verified serial recovery path. There is currently no validated image-upgrade path without UART; configuration backup and restore are separate operations.
- Stock U-Boot's `bootmiwifi` is needed. Booting a FIT directly with `bootm` triggered an HLOS panic on the tested unit, including with an unmodified Xiaomi FIT.
- The original Xiaomi firmware stays in slot 1 only if that slot is intact on **your** device. Verify it before changing slot 0. This repository cannot restore calibration (`ART`), bootloader or board data.
- Wi-Fi uses a mix of the base tree's root-PD firmware and 5 GHz files extracted from the owner's Xiaomi firmware. The mix works on the tested unit; it is not a general firmware compatibility guarantee.
- RAM is 256 MiB, with large reserved regions. About 35 MiB remained available during a short load test with both radios. Avoid assuming that extra services will fit.
- The 2.4 GHz test used one MediaTek MT7922 client. With that client's Bluetooth enabled, its Wi-Fi fell to one spatial stream and throughput varied widely. A second client has not confirmed the 2.4 GHz results.
- Ethernet flow control fixed a router-to-PC bottleneck on one link. With multiple Ethernet clients, pause frames could delay unrelated traffic; this has not been measured.
- Direct Wi-Fi-to-LAN bridge throughput, multi-client load, long uptime, WPA3, MLO and assisted roaming have not been validated.
- No public binary is provided: locally built images include proprietary Wi-Fi files. Do not commit or upload build outputs.

If you cannot reach a U-Boot prompt, boot the RAM image, or identify your flash layout exactly, stop before writing flash. See [recovery-and-rollback.md](recovery-and-rollback.md).
