# Findings from Xiaomi firmware 1.0.87

This is a static comparison of the RD15 stock firmware with the experimental
OpenWrt port. The original image used for the tested build has SHA-256
`cb2d7e40a74c33439fe61e78f1c2c08bf4effdb6617214118f3da783fd7a5c0a`.
The image and extracted binaries are not distributed here. File paths below
refer to the extracted Xiaomi root filesystem or its device tree.

| Area | Stock evidence | Port status / useful next test |
|---|---|---|
| 2.5 GbE | The stock DTB names MDIO addresses `0x0c` and `0x07` for PPE port 1. `/lib/miwifi/arch/lib_arch_phy_eth.sh` selects QCA8081 when the `0x0c` device exists and YT8821 otherwise. The default network config bridges `eth1` into LAN. | This unit previously reported YT8821 at `0x07`. The current DTS omits port 1 and the tested kernel has `CONFIG_MOTORCOMM_PHY` disabled, so this build cannot establish whether the physical port works. Test a YT8821-enabled initramfs, then 1/2.5 GbE link and traffic with a cable. |
| Low-memory Wi-Fi | `ini/internal/QCN6432_i.ini` has a `[256M]` profile with smaller descriptor/ring pools and monitor buffers; `ppe_ds_enable=0`. | This port already reduces ath12k allocations for the 256 MiB RD15. QSDK and ath12k parameter values are not interchangeable. Use memory and throughput measurements before changing another ring size. |
| Forwarding acceleration | The stock image contains ECM, PPE and Wi-Fi plugin modules and sets ECM acceleration to `auto`; `miqos` is disabled by default. | Existing `iperf3` runs terminate on the router, so they do not measure accelerated forwarding. A two-client Wi-Fi↔LAN benchmark is needed before tuning offload. Kernel 5.4 modules cannot be reused with this 6.18 build. |
| Ethernet CPU distribution | Stock `qca-nss-dp` startup distributes EDMA interrupts across cores and enables its RPS mode. | The present driver has different interfaces and already reaches about 933 Mb/s on 1 GbE. Only test IRQ/RPS changes if a loaded benchmark shows a CPU or queue bottleneck. |
| Thermal behavior | Stock `thermal.config` requests shutdown at 120 °C for its configured sensor. | The tested OpenWrt build exposes thermal zones and trips. No thermal tuning is justified by the present data. |
| Roaming | Stock `ssid-steering` config is present but disabled in the extracted default configuration. | 802.11r/k/v and usteer are under test. A real BSSID transition is still required to validate roaming. |

These are observations of firmware files, not a claim that each setting was
active on a running Xiaomi system. Hardware variants may use different PHYs.
The image also contains Xiaomi cloud and messaging services; this port does
not include them. The cause of any prior network message flood cannot be
attributed from this static image alone.

The live OpenWrt device tree already selects both MDIO pin groups
(GPIO25/26 and GPIO27/28) and enables PCS0. Its missing PHY/port nodes are
therefore a more specific next target than pin multiplexing. In
[Linux 6.18](https://github.com/torvalds/linux/blob/v6.18/drivers/net/phy/motorcomm.c),
the YT8821 driver starts in automatic SGMII/2500BASE-X mode unless the
initial interface is forced to `2500base-x`: it reports SGMII at 10/100/1000
Mb/s and 2500BASE-X at 2.5 Gb/s. The stock DTB's `sgmii` setting is a useful
starting point for a RAM test, provided the PPE/PCS driver supports this
change of interface. This has not been tested on the RD15 port.

The next hardware experiment should keep the installed slot intact: enable
the in-kernel [Motorcomm YT8821 driver](https://github.com/torvalds/linux/blob/v6.18/drivers/net/phy/motorcomm.c)
and the 2.5 GbE port in a RAM-boot image, verify the PHY/PCS probe on serial,
then connect a link partner and measure throughput. A failed probe must be
separated from a failed physical link before diagnosing hardware.
