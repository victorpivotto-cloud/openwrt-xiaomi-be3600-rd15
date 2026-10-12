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

Only after Stage A passes, add `port@1` using `pcs0_ch0`, the port-1 MAC/RX/TX
clocks and resets, and `phy-handle = <&yt8821>`. Start with
`phy-mode = "sgmii"`, which matches the Xiaomi DTB and allows the Linux 6.18
YT8821 driver to select SGMII at up to 1 Gb/s or 2500BASE-X at 2.5 Gb/s.
The Linux 6.18 PHY, phylink, PCS and PPE code has paths for that transition;
it remains unverified on this hardware. Start without
`managed = "in-band-status"`, so 1 Gb/s link state comes from MDIO rather
than requiring PCS in-band negotiation. If needed, test an in-band variant
separately. Do not infer success from a PHY ID alone.

Use a unique MAC derived from the board's existing base MAC, but confirm the
stock eth1 offset before making a permanent DTS. The installed image already
uses offsets 1, 2 and 3 for eth0 and the radios. An experimental image may use
offset 0 if the resulting address is distinct; this offset is unverified and
may already serve another stock function. Never publish the actual MAC.
Leave the interface out of all bridges and DHCP configuration.

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

No Stage B image has been built or booted yet. The current experiment branch
contains only Stage A source changes.
