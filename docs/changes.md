# Port changes

The files under `patches/` modify the pinned base tree; `openwrt-tree/` holds new files at their final paths. Consult the patch headers and file-level SPDX notices for upstream authorship and licensing.

| Component | Reason |
|---|---|
| RD15 DTS and image recipe | Match the stock `bootmiwifi` FIT name, 256 MiB RAM map, NAND ECC and UBI layout |
| YT9215S DSA backport | Provide the LAN switch driver and DSA tagger on Linux 6.18; based on upstream Linux work by David Yang |
| PPE ↔ switch `pause` on both fixed links | Prevent 2.5 Gb/s internal bursts from overwhelming a 1 Gb/s LAN egress; measured router-to-PC improvement from ~491 to 933–937 Mb/s |
| `ath12k` 990–994 patches | Reduce Wi-Fi memory use on a 256 MiB system and select the memory mode from installed RAM |
| `ath12k` 995 patch | Avoid RX page-fragment retention that caused out-of-memory failures under 1400-byte traffic |
| `rd15-slot` service | Mark a successful boot so Xiaomi U-Boot does not count it as a failed slot attempt; provide a controlled return to stock |
| safe UCI defaults and migration marker | Radios/DHCP/RA off after reset; preserve restored settings during an update |
| Guarded RD15 upgrade backend | Validate board/FIT/hash/layout, update fixed slot-0 UBI volumes and verify readback |
| YT921x 9991 | Correct VLAN-unaware FDB mapping, register width and stale dynamic-port takeover |
| PWM status LED | Blue after boot; orange for boot/failsafe/upgrade using native kernel PWM |
| mac80211 362 | Handle unsupported RU airtime without uninitialized overhead; retain conservative AQL accounting |
| ath12k 996 | Count descriptor exhaustion per pool without enlarging memory pools |
| hostapd 992 | Log key-install errno and class without key material or client addresses |
| envtools 015 | Write NAND by page, skip erased pages and verify each block |

The 2.5 GbE port is intentionally absent from the LAN definition because it is not yet supported. The old development logs contain several failed RAM boots and firmware combinations; this repository records the validated source state and test limits, not every experiment.
