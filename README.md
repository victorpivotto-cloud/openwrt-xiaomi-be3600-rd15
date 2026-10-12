# OpenWrt for the Xiaomi BE3600 2.5G (RD15) — experimental port

Device support for the **Xiaomi BE3600 2.5G, hardware RD15** (Qualcomm
IPQ5332 + QCN6432, 256 MiB RAM, 128 MiB SPI-NAND), on top of
[fivefold3/openwrt-gl-be3600](https://github.com/fivefold3/openwrt-gl-be3600)
(OpenWrt SNAPSHOT, target `qualcommbe/ipq53xx`, kernel 6.18).

> **Status: experimental, one unit tested.** It installs into the first of
> the two firmware slots and leaves the Xiaomi firmware in the second slot as
> a fallback. Installation **requires a 1.8 V serial console** and root on the
> stock firmware. Read [docs/limitations.md](docs/limitations.md) before
> trying it. You can brick your router; you are on your own.

This repository contains **only source**: a patch, new files for the OpenWrt
tree, a build config and helper scripts. It contains **no firmware images and
no Xiaomi/Qualcomm binaries**. The Wi-Fi firmware and board data the radios
need are copied by you, from the official Xiaomi firmware for your own device,
into your local build tree ([docs/vendor-firmware.md](docs/vendor-firmware.md)).

## What works (measured on one unit, October 2026)

| Area | State |
|---|---|
| Boot | Autonomous boot from NAND through the stock `bootmiwifi`; slot marked good so the bootloader does not fall back |
| Ethernet | 3 × 1 GbE LAN through the Motorcomm YT9215S (backported `yt921x` DSA driver); ~910–935 Mb/s TCP each way |
| Wi-Fi 2.4 GHz | AP, WPA2-PSK, HE20; ~131/~95 Mb/s TCP with a 2×2 client whose Bluetooth was off |
| Wi-Fi 5 GHz | AP, WPA2-PSK, HE80; ~390/~495 Mb/s TCP to one 2×2 client. FT-PSK (802.11r) + 11k/11v come up in hostapd; roaming not measured |
| Storage | SquashFS root + UBIFS overlay in the stock UBI volumes |
| Fallback | `rd15-slot boot-stock` returns to the Xiaomi slot; Xiaomi can switch back to OpenWrt |
| Memory | ~35 MB available with both radios up, flat over a 10-minute load |

Not supported: the 2.5 GbE port, `sysupgrade`, the generated `factory.ubi`,
MLO, WPA3 (untested). Details in [docs/status-and-testing.md](docs/status-and-testing.md).

## Documentation

| Document | Contents |
|---|---|
| [docs/hardware.md](docs/hardware.md) | SoC, memory map, flash layout, switch/PHYs, buttons, UART, boot flow |
| [docs/building.md](docs/building.md) | Reproducible build in a container |
| [docs/vendor-firmware.md](docs/vendor-firmware.md) | Which proprietary files are needed, why, and how to extract them locally |
| [docs/installing.md](docs/installing.md) | Serial console, RAM boot of the initramfs, backups, installation |
| [docs/recovery-and-rollback.md](docs/recovery-and-rollback.md) | Back to Xiaomi with and without SSH, restoring slot 0, what never to write |
| [docs/status-and-testing.md](docs/status-and-testing.md) | Test log and measurements |
| [docs/stock-firmware-findings.md](docs/stock-firmware-findings.md) | What the Xiaomi 1.0.87 image reveals about PHYs, Wi-Fi memory and forwarding |
| [docs/yt8821-ram-test.md](docs/yt8821-ram-test.md) | Staged, uninstalled test plan for the 2.5 GbE PHY and PPE port |
| [docs/limitations.md](docs/limitations.md) | Known problems, risks and open work |
| [docs/changes.md](docs/changes.md) | What every change in this port does and why |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Evidence and privacy rules for issues and pull requests |

## Repository layout

```
BASE_COMMIT                 base tree commit (fivefold3/openwrt-gl-be3600)
patches/                    changes to files that exist in the base tree (git apply)
openwrt-tree/               new files, at their paths in the OpenWrt tree
configs/                    diffconfig and pinned feeds of the tested build
scripts/prepare-tree.sh     clone base, apply patch, copy files (build host)
scripts/stage-vendor-firmware.sh  copy Wi-Fi blobs from YOUR Xiaomi firmware (build host)
scripts/install-slot0.sh    write OpenWrt into slot 0 (runs on the router, from RAM)
scripts/check-public-tree.sh  refuses binaries, keys and private data (used before commits)
docker/Dockerfile           build container (Ubuntu 24.04)
```

## Quick start (build only)

```sh
docker build -t owrt-build docker/
scripts/prepare-tree.sh ~/rd15-build
scripts/stage-vendor-firmware.sh --firmware miwifi_rd15_firmware_0321a_1.0.87.bin \
    ~/rd15-build --authorized-keys ~/.ssh/id_ed25519.pub
docker run --rm -it -v ~/rd15-build:/b/tree owrt-build bash -c \
    'cd /b/tree && ./scripts/feeds update -a && ./scripts/feeds install -a &&
     make defconfig && make -j"$(nproc)"'
```

Then follow [docs/installing.md](docs/installing.md). Images you build
contain Xiaomi/Qualcomm firmware: **do not publish them.**

## License and credits

Licensing is per file; see [LICENSING.md](LICENSING.md). The repository
default is GPL-2.0-only (as OpenWrt). Credits: [CREDITS.md](CREDITS.md).

Not affiliated with Xiaomi, Qualcomm, GL.iNet, Motorcomm or the OpenWrt
project. Trademarks belong to their owners.
