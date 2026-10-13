# Related IPQ5332 findings: Acer T7 and Flint 3

These are leads from other devices, **not RD15 test results**. Do not apply
their device trees, firmware, interrupt masks or update procedures to an RD15
without checking the hardware and measuring a reversible change.

## Acer Predator Connect T7: stock image extraction

The [Acer FOTA extractor forum post](https://forum.openwrt.org/t/reverse-engineered-acer-fota-stock-firmware-extractor-predator-connect-t7-ipq5332-w6x-mt7986/254115)
describes an IPQ5332 router whose vendor update service supplies FIT images.
It extracts kernels, DTBs and a stock root filesystem for port investigation.
The cloud handshake, keys, version graph and tool are **Acer-specific**; they
do not fetch Xiaomi RD15 images or provide an RD15 recovery route. Comparing
stock DTBs and filesystem settings is useful in principle, and this project
already documents that comparison for the owner's Xiaomi 1.0.87 image in
[stock-firmware-findings.md](stock-firmware-findings.md). FIT inspection with
`dumpimage` is already part of the RD15 build and installation checks.

## GL.iNet Flint 3: forwarding and interrupt load

In the [Flint 3 IPQ5332 discussion, post 161](https://forum.openwrt.org/t/gl-inet-flint-3-exploration-gl-be9300-ipq5332/250267/161),
the author reports that EDMA interrupts on their units landed on CPU0 by
default. Distributing EDMA/Wi-Fi IRQs and testing packet steering helped
diagnose a *routed/NAT* throughput bottleneck. Their AP bridge tests reached
1.79–1.92 Gb/s between 2.5 GbE ports without offload. They also warn that
enabling hardware flow offload on a branch without its PPE driver broke
connectivity. These are measurements and configuration observations on a
different board, switch, radio and software branch.

For the RD15, the installed 1 GbE ports already reach about 933 Mb/s in
router-endpoint tests. The household AP's initial DHCP/return-path failure
occurs before any throughput load; IRQ concentration or missing flow offload
has **not** been shown to cause it. Do not enable hardware flow offload or
copy the Flint 3 IRQ script as a speculative DHCP fix.

If a future *bridged* Wi-Fi-to-LAN or 2.5 GbE test shows a repeatable loaded
bottleneck, capture port-to-port `iperf3` throughput, per-core CPU and
`/proc/interrupts` counters before and during the run. Check the RD15's
actual IRQ names and effective affinity before a reversible, isolated IRQ/RPS
comparison. Track DHCP separately with packet captures on both sides of the
bridge. The Flint 3's multi-SSID firmware limits and PCIe/USB mux discussion
also cannot be assumed to apply to the RD15's QCN6432 and board layout.
