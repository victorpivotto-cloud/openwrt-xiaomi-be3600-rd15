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

Not measured: direct Wi-Fi↔LAN bridge throughput, simultaneous clients, WAN routing, 2.5 GbE, WPA3, MLO or real-world roaming. See [limitations.md](limitations.md).
