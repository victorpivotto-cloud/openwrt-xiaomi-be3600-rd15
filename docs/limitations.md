# Limitations and safety boundary

This is an experimental port tested on one Xiaomi BE3600 2.5G **RD15**. It is not an official OpenWrt target or a universal BE3600 image. Check the hardware ID before using any part of the installation procedure.

- The 2.5 GbE WAN/LAN port is not enabled in the DTS. Stock firmware has code paths for either a QCA8081 at MDIO `0x0c` or a YT8821 at `0x07`; this unit previously reported YT8821. The current kernel build also has `CONFIG_MOTORCOMM_PHY` disabled. Link and throughput have not been retested with this build. The three 1 GbE LAN ports work.
- `sysupgrade` and `factory.ubi` are not supported installation paths. Use the guarded slot-0 procedure only after a RAM boot, complete backups and a verified serial recovery path.
- Stock U-Boot's `bootmiwifi` is needed. Booting a FIT directly with `bootm` triggered an HLOS panic on the tested unit, including with an unmodified Xiaomi FIT.
- The original Xiaomi firmware stays in slot 1 only if that slot is intact on **your** device. Verify it before changing slot 0. This repository cannot restore calibration (`ART`), bootloader or board data.
- Wi-Fi uses a mix of the base tree's root-PD firmware and 5 GHz files extracted from the owner's Xiaomi firmware. The mix works on the tested unit; it is not a general firmware compatibility guarantee.
- RAM is 256 MiB, with large reserved regions. About 35 MiB remained available during a short load test with both radios. Avoid assuming that extra services will fit.
- The 2.4 GHz test used one MediaTek MT7922 client. With that client's Bluetooth enabled, its Wi-Fi fell to one spatial stream and throughput varied widely. A second client has not confirmed the 2.4 GHz results.
- Ethernet flow control fixed a router-to-PC bottleneck on one link. With multiple Ethernet clients, pause frames could delay unrelated traffic; this has not been measured.
- Direct Wi-Fi-to-LAN bridge throughput, multi-client load, long uptime, WPA3, MLO and assisted roaming have not been validated.
- No public binary is provided: locally built images include proprietary Wi-Fi files. Do not commit or upload build outputs.

If you cannot reach a U-Boot prompt, boot the RAM image, or identify your flash layout exactly, stop before writing flash. See [recovery-and-rollback.md](recovery-and-rollback.md).
