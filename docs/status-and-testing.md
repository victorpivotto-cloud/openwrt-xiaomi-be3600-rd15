# Status and measured tests

The bench results below are from **one RD15** in an isolated setup. Bench
rates are application throughput from `iperf3`, not PHY negotiation rates.
The router itself was the other `iperf3` endpoint; direct bridged Wi-Fi↔LAN
throughput remains unmeasured. A separate household phone test appears below.

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
It subsequently stopped enumerating on the PC, even after reconnecting it
on another USB 3 port. A separate 1 GbE USB adapter on the same RD15 jack
negotiated 1 Gb/s and completed 5/5 isolated pings, validating that speed's
fallback independently of the failed 2.5 GbE test partner.
These images were booted from RAM only; the installed slot still omits
the 2.5 GbE port. A stable device-tree MAC and persistent network setup
must be validated before installation.

The RD15 was rebooted into the unchanged installed slot-0 image after this
test. The stored FIT and rootfs matched their saved SHA-256 hashes, 10/10
management pings succeeded, and HTTP returned 200. A separate source branch
with a stable-MAC candidate compiled but was not booted or installed; see
[yt8821-ram-test.md](yt8821-ram-test.md).

## Three cold boots with the intended AP profile, 13 October 2026

The tested unit was powered off and on three times with a Home Assistant
smart plug. Each off interval exceeded ten seconds; loss of Ethernet carrier
and management ping confirmed that the unit was actually off. The serial
adapter stayed attached but was not used to start or recover any boot.

All three boots returned autonomously to the installed OpenWrt slot 0 with
`flag_boot_success=1` and no failed-slot counters. The tested `lan2` port
linked at 1 Gb/s. Management ping probes completed without loss (10/10,
5/5 and 10/10), and the HTTP interface returned 200. The home SSIDs remained
disabled; DHCP and RA services remained off. A final check found 36,912 KiB
MemAvailable, 8,408 KiB free overlay space and zero UBI bad PEBs. The unit
was left powered on and isolated from the household LAN pending a physical
AP swap. See [ap-deployment.md](ap-deployment.md).

## First household deployment, 13 October 2026

The tested unit moved to the household LAN as a 1 GbE bridge AP at
`192.0.2.4`. Both SSIDs came up. A pinned 5 GHz client authenticated but
the initial gateway DHCP OFFER did not reach it; even with a static IP it
could reach only the AP. Rejoining the two unplugged LAN ports to `br-lan`
after temporarily removing them restored forwarding. After that, DHCPACK,
gateway access and Internet access worked. A Wi-Fi reload and one cold
power cycle preserved the working path: after the cold boot, the 5 GHz
client received a lease and had 0% loss in 10 gateway and five Internet
pings. A later pinned 2.4 GHz client reproduced the DHCP/return-path failure
after that boot. A two-second `lan2` link cycle restored connectivity;
the client then obtained DHCP and passed 10/10 gateway and 3/3 Internet
pings. The cause remains open and the link cycle is only a workaround.
Details are in
[ap-deployment.md](ap-deployment.md).

## Household phone Internet test, 13 October 2026

The owner's Samsung phone was confirmed on this RD15's BSSIDs by Wi-Fi
scanner screenshots: `[redacted BSSID]` on 5 GHz `AP-5G` (channel 36, 80 MHz)
and `[redacted BSSID]` on 2.4 GHz `AP-2G` (channel 11, 20 MHz). Ookla
Speedtest reported **666/520 Mb/s** download/upload and 10 ms idle latency
on 5 GHz, and **126/81.6 Mb/s** and 11 ms idle latency on 2.4 GHz. The two
tests displayed the same server A Internet test server in an undisclosed location. They
are field results, not a controlled radio comparison or a measurement of
bridged LAN capacity.

The upstream gateway logged DHCPACK for the phone on both bands. For its
5 GHz connection, however, multiple DHCPOFFERs preceded DHCPACK by roughly
90 seconds. This is another sign of intermittent initial forwarding trouble
despite the eventual high throughput. See [ap-deployment.md](ap-deployment.md).

At a second position about 6 m from the AP, behind a partition and a roughly
70 cm wide MDF wardrobe/closet, the same phone remained on the RD15's 5 GHz
BSSID. A new Speedtest reported **624/479 Mb/s** and 20 ms idle latency;
the scanner showed −29 dBm and an 864 Mb/s link rate. This test selected
server B in an undisclosed location rather than the earlier server A server, so the two
rates do not isolate distance loss. The owner reported that reconnection
felt quick. Gateway logs show an immediate DHCPREQUEST/ACK for the existing
`192.0.2.82` lease at 11:20:50, which does not prove that a first lease
for a new client will be quick.

Not measured: direct Wi-Fi↔LAN bridge throughput, simultaneous clients, WAN routing, long-term 2.5 GbE stability, WPA3, MLO or real-world roaming. See [limitations.md](limitations.md).
