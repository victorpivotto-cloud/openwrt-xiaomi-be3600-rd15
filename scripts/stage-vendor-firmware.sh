#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
#
# Copy the proprietary Wi-Fi pieces the Xiaomi BE3600 RD15 port needs from a
# Xiaomi firmware YOU obtained into the files/ overlay of YOUR local OpenWrt
# build tree. Nothing is downloaded and nothing produced here may be
# redistributed or committed: the output is Xiaomi/Qualcomm property.
#
#   stage-vendor-firmware.sh --firmware miwifi_rd15_firmware_*_1.0.87.bin TREE [--authorized-keys FILE]
#   stage-vendor-firmware.sh --rootfs   EXTRACTED_STOCK_ROOTFS_DIR      TREE [--authorized-keys FILE]
#
# TREE is the OpenWrt checkout prepared by scripts/prepare-tree.sh.
#
# What is taken from Xiaomi 1.0.87, and why (see docs/vendor-firmware.md):
#  - QCN6432 (5 GHz) user-PD firmware q6_fw2 + iu_fw, WLAN.WBE.1.3.r4. The
#    WLAN.WBE.1.4 iu_fw shipped in the base tree asserts ("PHY0 IU") on this
#    board, and 1.4 q6_fw2 with the 1.3 iu_fw beacons but receives no data.
#  - Board data files bdwlan.b13 (IPQ5332, board-id 0x13) and bdwlan.b0060
#    (QCN6432, board-id 0x60), installed as board.bin.
# Per-unit calibration is NOT copied: the image reads it from the device's
# own 0:art partition at runtime.
#
# Requires: python3, unsquashfs (squashfs-tools); with --firmware also
# ubireader_extract_images (pip package "ubi_reader").
set -eu

usage() { sed -n '4,22p' "$0" >&2; exit 2; }

mode= src= tree= pubkey= allow_unverified=0
while [ $# -gt 0 ]; do
	case "$1" in
	--firmware) mode=firmware; src=$2; shift 2 ;;
	--rootfs) mode=rootfs; src=$2; shift 2 ;;
	--authorized-keys) pubkey=$2; shift 2 ;;
	--allow-unverified) allow_unverified=1; shift ;;
	-h|--help) usage ;;
	*) [ -z "$tree" ] || usage; tree=$1; shift ;;
	esac
done
[ -n "$mode" ] && [ -n "$tree" ] || usage
[ -f "$tree/target/linux/qualcommbe/dts/ipq5332-xiaomi-rd15.dts" ] ||
	{ echo "RD15 port not applied to $tree (run scripts/prepare-tree.sh)" >&2; exit 1; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT INT TERM

if [ "$mode" = firmware ]; then
	[ -f "$src" ] || { echo "no such file: $src" >&2; exit 1; }
	# Xiaomi "HDR1" container: up to 4 segment offsets at 0x10; each segment
	# header is 0x30 bytes (u16 0xbabe, u32 flash addr, u32 size, name@0x10).
	python3 -I - "$src" "$work/root.ubi" <<'PY'
import struct, sys
src, out = sys.argv[1], sys.argv[2]
d = open(src, 'rb').read()
if d[:4] != b'HDR1':
    sys.exit('not a Xiaomi HDR1 firmware image')
found = {}
for off in struct.unpack_from('<4I', d, 0x10):
    if not off:
        continue
    magic, = struct.unpack_from('<H', d, off)
    size, = struct.unpack_from('<I', d, off + 8)
    name = d[off + 0x10:off + 0x30].split(b'\0')[0].decode()
    if magic != 0xbabe:
        sys.exit('bad segment header at 0x%x' % off)
    found[name] = d[off + 0x30:off + 0x30 + size]
ver = found.get('xiaoqiang_version', b'').decode(errors='replace')
if "option HARDWARE 'RD15'" not in ver:
    sys.exit('firmware is not for hardware RD15')
rom = [l for l in ver.splitlines() if 'option ROM' in l]
print('firmware:', rom[0].strip() if rom else 'unknown ROM version')
if 'root.ubi' not in found:
    sys.exit('no root.ubi segment')
open(out, 'wb').write(found['root.ubi'])
PY
	(cd "$work" && ubireader_extract_images -o imgs root.ubi >/dev/null)
	sq=$(find "$work/imgs" -name '*vol-ubi_rootfs*' | head -n 1)
	[ -n "$sq" ] || { echo "no ubi_rootfs volume in the image" >&2; exit 1; }
	unsquashfs -no-xattrs -q -d "$work/rootfs" "$sq" \
		lib/firmware/IPQ5332 lib/firmware/qcn6432 \
		usr/share/xiaoqiang/xiaoqiang_version >/dev/null
	stock=$work/rootfs
else
	stock=$src
fi

fw=$stock/lib/firmware
[ -f "$fw/IPQ5332/WIFI_FW/q6_fw2.mdt" ] ||
	{ echo "not a Xiaomi RD15 rootfs: $stock" >&2; exit 1; }

# SHA-256 of the files in the official Xiaomi RD15 1.0.87 firmware
# (miwifi_rd15_firmware_0321a_1.0.87.bin). These are model-wide files, not
# per-unit data. The tested build used exactly these.
(cd "$fw" && sha256sum -c --quiet) <<'SUMS' || {
f26f08fa38ce2b055a796d56f009490d25963b1a43e2628a999ff9992af6c608  IPQ5332/WIFI_FW/q6_fw2.mdt
b1e41e0339d92e170fd9a75427e46f85ea767ec3f95d9a29f2c92569438e49d2  IPQ5332/WIFI_FW/q6_fw2.b00
b707241545a346265aab1ffb32ff64b55bf8f8dc1b56a46ef33ce3d15db11d33  IPQ5332/WIFI_FW/q6_fw2.b01
9994d9e49f6c27b0e989dabe9fdddedfbc49b9d7b097b82fad0947d498e3496f  IPQ5332/WIFI_FW/q6_fw2.b02
eb53499fb84ed2dbb06ceacdcc1fa62e81315e5bf1b76dc52e9115aeb023cbe8  qcn6432/iu_fw.mdt
5a176265205a7dfc6050ba8a50a7af20065aa0fff867c0cbb2d60df2edb06025  qcn6432/iu_fw.b00
b707241545a346265aab1ffb32ff64b55bf8f8dc1b56a46ef33ce3d15db11d33  qcn6432/iu_fw.b01
1efba95fcc1d72bc998e31f78e6662c6162e8295dbfe165bf56384235d0f7750  qcn6432/iu_fw.b02
08fee5b77f62526decad36f718dde914255d8d6d6e483b92a12dfeaa97188af4  qcn6432/bdwlan.b0060
314510e0bf0ee2e5341c82e17f8a7e5af7f3948994fbb4ef440de1b0931394de  IPQ5332/bdwlan.b13
SUMS
	if [ "$allow_unverified" = 1 ]; then
		echo "WARNING: vendor files differ from the tested 1.0.87 set" >&2
	else
		echo "vendor files differ from the tested 1.0.87 set; refusing" \
		     "(--allow-unverified to override, untested)" >&2
		exit 1
	fi
}

dst=$tree/files/lib/firmware/ath12k
mkdir -p "$dst/QCN6432/hw1.0" "$dst/IPQ5332/hw1.0"
for f in q6_fw2.mdt q6_fw2.b00 q6_fw2.b01 q6_fw2.b02; do
	install -m 0644 "$fw/IPQ5332/WIFI_FW/$f" "$dst/QCN6432/hw1.0/$f"
done
for f in iu_fw.mdt iu_fw.b00 iu_fw.b01 iu_fw.b02; do
	install -m 0644 "$fw/qcn6432/$f" "$dst/QCN6432/hw1.0/$f"
done
install -m 0644 "$fw/qcn6432/bdwlan.b0060" "$dst/QCN6432/hw1.0/board.bin"
install -m 0644 "$fw/IPQ5332/bdwlan.b13" "$dst/IPQ5332/hw1.0/board.bin"
# The base tree's QCN6432 board-2.bin would be tried before board.bin.
rm -f "$dst/QCN6432/hw1.0/board-2.bin"

if [ -n "$pubkey" ]; then
	grep -q 'PRIVATE KEY' "$pubkey" && { echo "refusing a private key" >&2; exit 1; }
	mkdir -p "$tree/files/etc/dropbear"
	install -m 0600 "$pubkey" "$tree/files/etc/dropbear/authorized_keys"
	chmod 0700 "$tree/files/etc/dropbear"
fi
# The image keeps the build host's modes; dropbear refuses group-writable
# directories on the authorized_keys path.
find "$tree/files" -type d -exec chmod go-w {} +

echo "staged vendor Wi-Fi files into $dst (do not redistribute the build output)"
