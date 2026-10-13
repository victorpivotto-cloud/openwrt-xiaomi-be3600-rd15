# RD15 YT8821 2.5 GbE RAM test

This is a **RAM-boot experiment** for the tested RD15 unit, whose stock
firmware identified a Motorcomm YT8821 (PHY ID `0x4f51ea19`) at MDIO address
`0x07`. The installed OpenWrt slot does not describe PPE port 1 or include
`CONFIG_MOTORCOMM_PHY`; lack of link in that image says nothing about the
physical jack.

The two stages below use initramfs images booted over the 1.8 V serial
console. Use **only** the `*-initramfs-uImage.itb` output. A normal build also
produces `factory.ubi` and `sysupgrade.bin`; neither is part of this test or
a validated installation route. Keep the known-good slot and stock fallback
intact. Keep the router isolated from the home LAN, and do not add the
experimental interface to `br-lan`. Preserve the existing serial log and
verify the image SHA-256 before each RAM boot.

## Stage A: PHY discovery only

The experiment branch adds `ethernet-phy@7` under `&mdio` and builds
`CONFIG_MOTORCOMM_PHY=y` in the shared ipq53xx kernel config. It leaves PPE
`port@1` absent. GPIO51 remains the shared MDIO bus reset; there must be no
additional PHY-specific reset that would disrupt the YT9215S switch serving
the 1 GbE ports.

After boot, verify the PHY ID at
`/sys/bus/mdio_bus/devices/<bus>:07/phy_id` and the bound `driver` symlink,
then inspect `dmesg`. There is no netdev for this PHY at Stage A. A pass
proves ID read, driver probe and lack of regression to the switch; it does
**not** exercise the PHY's link setup, status reporting or 2.5 GbE data path.
Check that `eth0` and `lan1`–`lan3` still probe and carry traffic. A PHY
probe failure, MDIO bus failure or missing switch ends this stage; the RAM
image can be left by rebooting. Do not add PPE port 1 merely to obtain a
netdev.
Run the same LAN benchmark used for the known-good build to detect a switch
regression.

## Stage B: PPE port 1

Before building Stage B, fix the PPE driver's error unwind in
`ppe_port_mac_init()` (`drivers/net/ethernet/qualcomm/ppe/ppe_port.c` in the
pinned kernel). When `edma_port_setup()` fails on the first port, the code
decrements index `i` from zero to −1, skips its first cleanup loop, then
enters `while (i)` and indexes ports below zero. The earlier QCA8081 probe
failure reached this path. A valid PHY probe in Stage A reduces one trigger
but does not make the PPE error path safe. Validate the fix in a separate
build before enabling PPE port 1.
The guard patch was build-tested on the Stage A DTS; its failure path has
not been exercised on hardware.

Only after Stage A passes, add `port@1` using `pcs0_ch0`, the port-1 MAC/RX/TX
clocks and resets, and `phy-handle = <&yt8821>`. Start with
`phy-mode = "sgmii"`, which matches the Xiaomi DTB and allows the Linux 6.18
YT8821 driver to select SGMII at up to 1 Gb/s or 2500BASE-X at 2.5 Gb/s.
The Linux 6.18 PHY, phylink, PCS and PPE code has paths for that transition;
it remains unverified on this hardware. Start without
`managed = "in-band-status"`, so 1 Gb/s link state comes from MDIO rather
than requiring PCS in-band negotiation. If needed, test an in-band variant
separately. Do not infer success from a PHY ID alone.

For the Stage B RAM test, the DTS omits `nvmem-cells`; the driver assigns a
random MAC to `eth1`. Confirm the stock eth1 offset before making a permanent
DTS. The installed image already uses offsets 1, 2 and 3 for eth0 and the
radios; offset 0 is unverified and may already serve another stock function.
Never publish the actual MAC. Leave the interface out of all bridges and DHCP
configuration.

Observe the entire serial boot. Verify the port's PHY/PCS/phylink probe, then
connect a known-good 1 GbE partner and a 2.5 GbE partner in turn. For each,
record negotiated mode, link changes, error counters and bidirectional
`iperf3`. Also rerun the 1 GbE switch benchmark. An `iperf3` endpoint on the
router tests the local network path; forwarded Wi-Fi↔LAN performance needs two
separate clients.

If the PPE probe oopses or `eth0` regresses, capture the serial log and return
to the installed slot. A prior attempt with absent QCA8081 at `0x0c` timed
out on PHY reset and then oopsed in the PPE error path. If only 2.5 Gb/s
negotiation fails, a *separate* RAM image forcing `2500base-x` may isolate a
dynamic mode-switch problem; it cannot validate 1 Gb/s fallback.

## Offline checks before building

- Confirm `pcs0_ch0` and the port-1 NSSCC clock/reset names in the pinned
  `ipq5332.dtsi` and `qcom,ipq5332-nsscc.h`.
- Confirm the generated kernel `.config` contains `CONFIG_MOTORCOMM_PHY=y`.
- Inspect the generated DTB and FIT; save image hashes privately.
- Keep the actual PHY/MAC identifiers and all device-specific calibration or
  backup data out of public commits and build logs.

The Stage A source is preserved on `experiment/yt8821-ram-test`. The
`experiment/yt8821-port1-ram-test` branch adds the PPE guard and port 1 for a
separate image. Both private initramfs variants compiled and their FIT/DTB
hashes were checked. Both were booted from RAM on 12 October 2026; neither
branch changes the installed slot.

## Observed results on the tested RD15

- Stage A bound `90000.mdio-1:07` to `YT8821 2.5Gbps PHY` with PHY ID
  `0x4f51ea19`. The gigabit switch remained available; 20 management pings
  had zero loss.
- Stage B created `eth1` on that PHY and booted without an oops. With a
  RTL8156B USB adapter in the physical 2.5 GbE jack, both ends negotiated
  2.5 Gb/s full duplex. `eth1` was kept outside `br-lan` and assigned only
  a temporary isolated address.
- Local TCP throughput to the router was 1.68 Gb/s PC→RD15 and 2.34 Gb/s
  RD15→PC with one stream, then 2.35 Gb/s PC→RD15 with four streams.
  Router `eth1` reported zero RX/TX errors and drops.
- A four-stream RD15→PC run stalled after roughly three seconds. The PC
  logged RTL8156B USB read timeouts (`-110`), SuperSpeed reset attempts and
  `r8152` transmit timeouts. The Ethernet link stayed negotiated at 2.5
  Gb/s. This run does not qualify sustained throughput or identify whether
  the USB adapter, port, cable or power path failed.
- The RTL8156B subsequently failed USB enumeration (`-110` and `-71`) even
  after reconnecting it on another USB 3 port. With a separate 1 GbE USB
  adapter plugged into the same RD15 jack, the link negotiated 1 Gb/s and
  all five isolated pings succeeded. This verifies the YT8821's 1 Gb/s
  fallback independently of the failed 2.5 GbE test partner.

Before a persistent image, derive a stable `eth1` MAC from verified device
data, decide the default network role, test 1 Gb/s fallback on this jack,
repeat sustained traffic with a reliable 2.5 GbE partner, and validate
reboot and rollback. The installed slot still has no PPE port 1 support.

## Stage C: stable MAC candidate

The `experiment/yt8821-stable-mac-ram-test` branch adds
`nvmem-cells = <&base_macaddr 1>` to `eth1`. This deliberately reuses the
already validated LAN MAC cell of `eth0`; it does not guess a new offset or
embed a per-unit address. It is suitable for a future LAN bridge, but while
`eth1` remains separate it must stay on an isolated test subnet and must
not share an upstream Ethernet segment with `eth0`/`lan1`–`lan3`.
Boot this variant from RAM first. Verify `addr_assign_type=0` and equality
between `eth0` and `eth1` without printing the address. Then repeat link,
traffic and gigabit-switch checks. This branch is not an installation
approval or a network-default change.

The Stage C source compiled on 12 October 2026. The generated initramfs FIT
is 16,049,856 bytes (SHA-256
`d5a273a1538e055aecbaf3a322d3111a7bc32d733560afb0eb93c1ee649d7747`).
The generated DTB contains `nvmem-cells` and `nvmem-cell-names` on Ethernet
port 1, and the kernel has `CONFIG_MOTORCOMM_PHY=y`. **Stage C has not been
booted or installed**; the tested RD15 was returned to its existing slot-0
image after the Stage B tests.
