# 1 GbE AP deployment on the tested RD15

The installed OpenWrt slot 0 is configured as a bridged access point for
the owner's household LAN. The physical swap from the former bedroom AP
was performed on 13 October 2026. The unit had passed three cold boots in
the isolated bench setup without serial intervention.

## Prepared configuration

- Static management address: `192.168.1.4/24`, gateway/DNS `192.168.1.1`.
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
3. Power on. After boot, confirm `192.168.1.4` answers from the household
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
answered on `192.168.1.4` (five of five pings and HTTP 200). DHCP/RA
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

The forwarding issue **recurred** with the first pinned 2.4 GHz `MOV` client
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
the initial forwarding fault. Both screenshots show the same Vtal Internet
test server in Porto Alegre.

At a second household position roughly 6 m away, with a partition and an
MDF closet/wardrobe between client and AP, the same phone stayed on the RD15
5 GHz BSSID and measured 624/479 Mb/s and 20 ms idle latency. The user
reported a quick reconnection; the gateway logged an immediate DHCP renewal
for the phone's existing lease. The test used a different Internet server
than the near-AP result, and a quick renewal does not validate first-lease
behavior for another client.

Direct bridged throughput, multiple clients and roaming in the final room
still require testing. Keep the former AP intact and do not rely on this RD15
as the sole access point until the forwarding fault is understood and fixed.

## Upgrade and recovery boundary

The generated `sysupgrade.bin` and `factory.ubi` are **not** supported
installation paths. The installed `platform.sh` rejects `xiaomi,rd15`,
and generic NAND sysupgrade would recreate the stock-compatible static
`kernel` volume incorrectly. Configuration changes and backups work, but
flashing another image through LuCI is not validated. After UART removal,
serial recovery requires opening the case again. The stock Xiaomi slot 1
remains a fallback, but it should be selected only with the household LAN
disconnected because the stock firmware may run DHCP.
