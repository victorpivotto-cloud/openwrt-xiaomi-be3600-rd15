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
| safe UCI defaults | Boot with radios and DHCP/RA disabled after reset to avoid interfering with another network |

The 2.5 GbE port is intentionally absent from the LAN definition because it is not yet supported. The old development logs contain several failed RAM boots and firmware combinations; this repository records the validated source state and test limits, not every experiment.
