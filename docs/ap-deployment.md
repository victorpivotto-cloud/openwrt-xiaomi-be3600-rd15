# 1 GbE AP deployment on the tested RD15

The installed OpenWrt slot 0 is configured as a bridged access point for
the owner's household LAN. This page records a **tested predeployment
state**, not a claim that the physical swap has happened. The tested unit
passed three cold boots on 13 October 2026 without serial intervention.

## Prepared configuration

- Static management address: `192.0.2.4/24`, gateway/DNS `192.0.2.1`.
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
3. Power on. After boot, confirm `192.0.2.4` answers from the household
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

## Upgrade and recovery boundary

The generated `sysupgrade.bin` and `factory.ubi` are **not** supported
installation paths. The installed `platform.sh` rejects `xiaomi,rd15`,
and generic NAND sysupgrade would recreate the stock-compatible static
`kernel` volume incorrectly. Configuration changes and backups work, but
flashing another image through LuCI is not validated. After UART removal,
serial recovery requires opening the case again. The stock Xiaomi slot 1
remains a fallback, but it should be selected only with the household LAN
disconnected because the stock firmware may run DHCP.
