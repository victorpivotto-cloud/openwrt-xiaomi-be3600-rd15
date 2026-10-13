# Status and measured tests

All results below are from **one RD15** in an isolated bench setup. Rates are application throughput from `iperf3`, not PHY negotiation rates. The router itself was the other `iperf3` endpoint; direct bridged Wi-Fi↔LAN throughput remains unmeasured.

## Installed version and independent build

On 11 October 2026, `/etc/openwrt_release` on the running router reported
`OpenWrt SNAPSHOT r35705-e46ea77ba4`, target `qualcommbe/ipq53xx`;
`uname -r` reported `6.18.39`. This is the local RD15 port, not an official
OpenWrt release. The running image was installed from the development build.

A separate clean tree prepared from this public repository and the pinned
base/feeds completed a container build on the same date. Its target output
contains an initramfs FIT, `factory.ubi` and `sysupgrade.bin`; all entries in
the generated `sha256sums` verified. The build reports the same revision and
kernel version. Its initramfs FIT SHA-256 is
`06a2ac76a44d1f2661259911d16b2d867b200847af5790da4461ade891fdd2e0`.
These newly built images have **not** been booted or installed on the router.
The generated `factory.ubi` and `sysupgrade.bin` remain unsupported
installation paths; see [limitations.md](limitations.md).

| Link | PC → RD15 | RD15 → PC | Conditions |
|---|---:|---:|---|
| 1 GbE LAN | ~900 Mb/s | 933–937 Mb/s | USB Ethernet client, after CPU-switch flow-control fix |
| 5 GHz Wi-Fi | 371–398 Mb/s | 473–508 Mb/s | channel 36, HE80, 2×2 client, strong signal |
| 2.4 GHz Wi-Fi | ~131 Mb/s | ~95 Mb/s | channel 11, HE20, MediaTek MT7922 client **Bluetooth off** |

With Bluetooth on in that client, its 2.4 GHz association dropped to one stream/MCS 2 and the initial upload runs were 10, 73 and 31 Mb/s. Swapping the RD15 radio firmware did not improve this and was reverted. With Bluetooth off, the client negotiated two HE streams at MCS 9–11. This does not prove behavior for every client.

Before the `pause` fix, the Ethernet router-to-PC runs were 492, 490 and 492 Mb/s with roughly 13,000 TCP retransmissions per run. After the fix they were 937, 933 and 933 Mb/s with 47–63 retransmissions. Booting from NAND, slot-success marking and one cold power cycle passed after that change.

Both APs authenticated a test client and survived 12,000 ICMP probes of 1400 bytes per band without an out-of-memory event. Available RAM was roughly 34–37 MiB. This is a short stress test; it is not an endurance claim.

## Isolated 5 GHz endurance test, 11–12 October 2026

A temporary laboratory SSID with WPA2 and 802.11r/k/v was enabled for a
15-hour radio test; the normal household SSIDs stayed off. One MT7922 client
remained on channel 36/HE80 at −38 to −36 dBm. All 178 five-minute ping
samples had 0% loss, with no BSSID change or router reboot. Router thermal
readings stayed between 60.8 and 63.8 °C. The original wireless and
`usteer` configurations were restored and hash-checked afterward; no AP
remained active.

Fourteen hourly `iperf3` pairs finished without tool errors. Median
throughput was **148.5 Mb/s client→RD15** and **233.8 Mb/s RD15→client**.
Ranges were 121.5–341.2 and 208.0–508.2 Mb/s respectively; only one
pair reached the earlier ~340/500 Mb/s class. During several slower runs,
neither the router nor the client showed sustained CPU saturation or
`softnet` drops. PHY rates and RSSI stayed high. This does not identify
whether the remaining variation is in the AP, client or radio environment;
the AP should not replace a proven household AP on throughput grounds yet.

The test confirmed 802.11k neighbor advertisement and a response to an
802.11v transition request, but the client was pinned to a BSSID and refused
the transition. It did **not** validate a real 802.11r roam. Forwarded
Wi-Fi↔LAN throughput and multi-client behavior also remain unmeasured.

## Isolated 1 GbE endurance test, 11–12 October 2026

The LAN test collected 191 samples over 16 hours. Every sample had 0% loss
across ten ICMP probes and a valid isolated route. Router uptime increased
continuously, no UBI bad block appeared, and the kernel error count remained
at its single baseline NAND driver warning. Available memory ranged from
28,040 to 36,636 KiB and recovered to 33,264 KiB by the last sample. Free
overlay space stayed within 8,408–8,412 KiB. The temporary route was removed
at the end. Wireless settings were restored and hash-checked, and no RD15 AP
remained active.

## Experimental 2.5 GbE RAM boot, 12 October 2026

An experimental initramfs with `CONFIG_MOTORCOMM_PHY` identified PHY
`0x4f51ea19` at MDIO address `0x07` as YT8821. A second RAM-only image
connected PPE port 1 to that PHY. Its `eth1` interface negotiated
**2.5 Gb/s full duplex** with a RTL8156B USB adapter. In an isolated local
`iperf3` test, one stream reached 1.68 Gb/s PC→RD15 and 2.34 Gb/s
RD15→PC; four streams reached 2.35 Gb/s PC→RD15 with zero TCP
retransmissions. The PHY and Ethernet port are functional on this unit.

A four-stream RD15→PC run stalled after three seconds. The PC then logged
USB read timeouts (`-110`), SuperSpeed reset attempts and `r8152` transmit
timeouts, while RD15 `eth1` stayed at 2.5 Gb/s with zero RX/TX errors and
drops. The USB adapter, its connection and power need separate validation.
These images were booted from RAM only; the installed slot still omits
the 2.5 GbE port. A stable device-tree MAC and persistent network setup
must be validated before installation.

Not measured: direct Wi-Fi↔LAN bridge throughput, simultaneous clients, WAN routing, long-term 2.5 GbE stability, WPA3, MLO or real-world roaming. See [limitations.md](limitations.md).
