# Completed work and open improvements

Status after the 26 October 2026 update; experimental, one RD15 tested.
Checked items describe the stated test scope, not universal certification.

## Completed in the tested path

- [x] Autonomous slot-0 boot with the stock bootloader and intact stock slot.
- [x] Three 1 GbE LAN ports through the YT921x DSA backport.
- [x] Controlled stale-FDB DHCP reproduction and correction, with complete
  first-lease exchanges on both bands.
- [x] Guarded update of an existing installation through LuCI, exercised in
  Chrome with settings kept and payload readback checked.
- [x] Safe reset defaults and keep-settings migration marker.
- [x] Blue/orange PWM status LED with OpenWrt boot-state aliases.
- [x] Airtime unknown-rate handling and conservative AQL fallback.
- [x] Page-based NAND environment writes, block readback and successful
  automatic boot-success marking in the final installed image.
- [x] Per-pool TX exhaustion counters and key-install errno diagnostics.

## Next qualification

- [ ] **TX descriptor exhaustion:** correlate per-pool counters, completions,
  workload and real client loss. Distinguish bursts from retained descriptors;
  do not enlarge pools without measurements on the 256 MiB device.
- [ ] **FT roaming:** test both directions with adequate signal and clean
  client state; correlate key installation, authorization and bidirectional
  traffic. ENOENT before association does not explain every rejection.
- [ ] **HE/OFDMA performance:** measure forwarded load and AQL behavior when
  RU rate estimates use the conservative fallback.
- [ ] **NAND/boot endurance:** repeat controlled cold boots and success-flag
  writes, retaining CRC/readback evidence; power-loss behavior remains separate.
- [ ] **Memory and thermal baseline:** collect longer trends and compare stock
  only under matched placement, ambient conditions, clients and workload.
- [ ] **2.5 GbE deployment:** qualify the RAM-tested YT8821 branch with a stable
  test partner before enabling it in the persistent image.
- [ ] **Multi-port and multicast:** exercise simultaneous wired clients,
  VLAN-aware forwarding and hardware MDB behavior separately from the FDB fix.
- [ ] **Additional radio modes:** qualify WPA3, MLO and broader client coverage.

When reporting a result, distinguish first DHCP grant from renewal, a PHY rate
from application throughput, association from successful traffic, and an
accumulated counter from measured packet loss. Keep original captures and
device-specific recovery data private.
