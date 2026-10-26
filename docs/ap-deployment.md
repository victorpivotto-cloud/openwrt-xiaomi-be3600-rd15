# 1 GbE AP deployment on the tested RD15

**Update, 26 October:** the installed image contains the controlled DHCP/FDB
fix and the LED/airtime/environment improvements. Read the dated observations
below as history. Current qualification and open work are in
[the update record](update-2026-10-26.md) and [roadmap](roadmap.md).

The installed OpenWrt slot 0 is configured as a bridged access point for
the owner's household LAN. The physical swap from the former bedroom AP
was performed on 13 October 2026. The unit had passed three cold boots in
the isolated bench setup without serial intervention.

## Prepared configuration

- Example management address: `192.0.2.4/24`, gateway/DNS `192.0.2.1`.
  Addresses below use a documentation-only subnet; substitute your own LAN.
- Bridge: `lan1`, `lan2`, `lan3`. The `lan2` jack was used for the 1 GbE
  endurance and cold-boot checks. The 2.5 GbE jack is not enabled in the
  installed image.
- DHCPv4, DHCPv6, RA and NDP service disabled; `dnsmasq` and `odhcpd`
  disabled and stopped. The upstream AX3000T remains the sole gateway and
  DHCP server.
- Household 2.4 and 5 GHz SSIDs are configured but **disabled** until the
  new AP is on the household LAN and its management path is verified.
  Radio settings, including credentials, are private to the owner and are
  not part of this repository.
- SSH and HTTP management listen on the static IPv4 address. There is no
  global IPv6 management address on `br-lan`.

## Physical handoff and verification

1. Power off the RD15. If removing serial leads, keep power and the USB
   serial adapter disconnected while working. The UART uses **1.8 V**;
   never attach an ordinary 3.3/5 V TX or VCC. Remove or insulate loose
   conductors so they cannot contact the board or metal shield when the
   case closes.
2. Disconnect the isolated bench cable. Connect **one** cable from the
   household LAN to the same physical 1 GbE jack that held the tested
   bench adapter (`lan2`). Do not use the 2.5 GbE jack and do not leave the
   PC bench cable connected at the same time.
3. Power on. After boot, confirm the configured management address answers from the household
   LAN and the link is 1 Gb/s. Confirm OpenWrt slot 0 is marked good,
   `dnsmasq`/`odhcpd` remain stopped, and no new DHCP server appeared.
4. Only then enable the two AP interfaces. Verify client association,
   Internet access, address/gateway/DNS from the upstream AX3000T, and
   roaming to the other APs. Measure throughput in the final room; the
   isolated tests do not qualify real-world Wi-Fi-to-LAN performance.
5. Keep the former AP intact until the replacement works with the owner's
   clients. To roll back the physical swap, power off the RD15 and
   reconnect the former AP.

The owner's private deployment report contains the exact local helper
commands and the private configuration backup. Do not upload those backups,
Wi-Fi passwords, device calibration or serial logs to this repository.

## Initial household-LAN result, 13 October 2026

The household cable was connected to the previously tested `lan2` jack.
OpenWrt returned on slot 0, the link negotiated 1 Gb/s and management
answered on its configured management address (five of five pings and HTTP 200). DHCP/RA
services on the RD15 stayed off. After enabling the radios, both prepared
SSIDs were visible; the 5 GHz BSSID joined the other APs' `usteer` view.

The **first** pinned 5 GHz client connection authenticated but received no
DHCP lease. The household gateway logged DISCOVER and OFFER, while a
temporary static-IP client reached the RD15 itself but could not reach the
gateway. Temporarily removing and restoring the two unplugged LAN ports
from `br-lan` made the return path work. The gateway then issued DHCPACK,
and the client reached the gateway and an Internet IP through the RD15.
This observation identifies a **transient bridge/switch forwarding issue**;
its root cause is not established. The client retained connectivity through
a Wi-Fi reload. A later cold power cycle with the radios enabled returned
to slot 0 and the pinned 5 GHz client obtained DHCP immediately, with
10/10 gateway and 5/5 Internet pings.

The forwarding issue **recurred** with the first pinned 2.4 GHz client
after that cold boot. Association succeeded, but the gateway repeatedly
logged DHCP DISCOVER/OFFER without ACK. With a temporary static IP, the
client reached the RD15 but not the gateway. Removing the two unplugged
bridge ports alone did not restore this connection. Cycling the `lan2`
carrier down/up for two seconds restored gateway reachability, then the
client obtained a DHCP lease and completed 10/10 gateway and 3/3 Internet
pings. The unplugged ports were returned to the bridge and connectivity
remained up. This is a runtime workaround, **not a proven fix**; the root
cause and behavior for the next new client remain unknown.

A subsequent phone test in the bedroom reached 666/520 Mb/s through the
RD15's 5 GHz BSSID and 126/81.6 Mb/s through its 2.4 GHz BSSID in Internet
speed tests. Both connections eventually received DHCP from the household
gateway, but the 5 GHz connection had repeated DHCP OFFERs for about 90
seconds before its ACK. Good throughput after association does not resolve
the initial forwarding fault. Both screenshots show the same Internet
test server; its operator and location are omitted.

At a second household position roughly 6 m away, with a partition and an
MDF closet/wardrobe between client and AP, the same phone stayed on the RD15
5 GHz BSSID and measured 624/479 Mb/s and 20 ms idle latency. The user
reported a quick reconnection; the gateway logged an immediate DHCP renewal
for the phone's existing lease. The test used a different Internet server
than the near-AP result, and a quick renewal does not validate first-lease
behavior for another client.

Controlled direct bridged throughput and roaming tests in the final room
remain open. Keep the former AP available for rollback while the forwarding
fault remains unexplained.

## Three-day household observation, 13–16 October 2026

The AP was reachable at all 73 hourly checks (3/3 ICMP probes each); these
checks do not establish uninterrupted availability between samples. One
reboot was observed between two checks on 14 October; its cause was not
confirmed. Afterward the AP stayed on the same boot through the final check.
The `lan2` uplink remained up at 1 Gb/s, with zero recorded RX/TX errors.
Both SSIDs stayed active and clients used both bands. Available memory in
the periodic samples ranged from about 31 to 36 MiB, the overlay had about
8.2 MiB free, and UBI reported no bad physical eraseblocks. Local DHCP and
RA services stayed disabled.

Client onboarding and roaming remained intermittent. A phone associated by
802.11r FT but temporarily had no IPv4 connectivity while the upstream
gateway logged repeated DHCP DISCOVER/OFFER without REQUEST/ACK; a normal
reassociation restored service. A 2.4 GHz client without FT and a projector
on 5 GHz also experienced repeated offers before successful connections.
The projector later streamed video normally. FT key-addition errors were
also seen on the other household APs, so this is not established as an RD15
driver-only issue. Repeated gateway offers do not identify the failing hop,
and a lease renewal is different from an initial grant. An isolated
`lan2 rx_dropped` increase is not proof of client packet loss.

The AP remained in service at the end of the observation, booted from the
installed OpenWrt slot 0 with the boot-success flag set. Next diagnostic
work is to capture DHCP/ARP on both sides of the bridge during a reproduced
failure and run a controlled FT A/B test. Neither the fault nor 2.5 GbE
support is resolved by this household observation.

## Controlled DHCP/FDB follow-up, 19–20 October

The failure was reproduced when a client had first been learned on the
wired uplink and then moved to Wi-Fi. Bridge software learned the new
location, while the switch hardware retained the old forwarding entry.
The correction maps bridge VID 0 to the switch's VLAN-unaware FID 4095,
preserves full-width register arguments and replaces a stale dynamic port
when installing the static host/CPU entry. Existing static-entry merge is
preserved. STP and MDB remapping were not changed.

The candidate passed 14 complete DHCP DORA exchanges (11 on 5 GHz and three
on 2.4 GHz); 13 had a dynamic hardware entry proven before association.
Three further DORAs passed against the actual upstream household gateway.
This validates the controlled stale-FDB path; it does not establish that
every onboarding or FT issue has the same cause. VLAN-aware forwarding,
hardware multicast and simultaneous multi-port behavior remain open.

## Upgrade and recovery boundary

Existing installations can use the guarded RD15 sysupgrade through LuCI;
two interactive Chrome updates completed on 26 October, with settings
retained and kernel/rootfs readback matching the input. The update does not
recreate the fixed UBI volumes or write the stock slot. It is not an initial
stock-to-OpenWrt path; `factory.ubi` remains unqualified.

After UART removal, serial recovery requires opening the case again. The
stock Xiaomi slot remains a fallback and should be selected only with the
normal LAN disconnected because stock firmware may run DHCP. See
[upgrading.md](upgrading.md) and [recovery-and-rollback.md](recovery-and-rollback.md).
