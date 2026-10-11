#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
#
# Install OpenWrt into slot 0 (mtd "rootfs") of a Xiaomi BE3600 RD15.
# Runs ON THE ROUTER, as root, from the OpenWrt initramfs booted in RAM
# (stock U-Boot passes ubi.mtd=rootfs when flag_boot_rootfs=0, so slot 0 is
# attached as ubi0):
#
#   sh install-slot0.sh FIT SHA256_FIT SQUASHFS SHA256_SQUASHFS
#
# FIT      = build_dir/.../xiaomi_rd15-uImage.itb   (kernel FIT, no initramfs)
# SQUASHFS = build_dir/.../root.squashfs
#
# Resulting volumes in slot 0 (stock names kept so bootmiwifi finds them):
#   ubi0_0 kernel       <- OpenWrt FIT
#   ubi0_1 ubi_rootfs   <- OpenWrt SquashFS, resized to 16 MiB
#   ubi0_2 rootfs_data  <- (re)created with all free LEBs; OpenWrt formats it
#
# BACK UP ALL MTD PARTITIONS AND THE SLOT 0 VOLUMES FIRST (docs/installing.md).
# Never touches slot 1 ("rootfs_1"), ART, bootloaders or partition tables.
set -u
fit=${1:?FIT} fit_sum=${2:?SHA256_FIT} sq=${3:?SQUASHFS} sq_sum=${4:?SHA256_SQUASHFS}
die() { echo "INSTALL_FAILED: $*"; exit 1; }

[ "$(cat /tmp/sysinfo/board_name)" = xiaomi,rd15 ] || die "board"
case " $(cat /proc/cmdline) " in *" ubi.mtd=rootfs "*) ;; *) die "not attached to slot rootfs" ;; esac
[ "$(cat /sys/class/ubi/ubi0/mtd_num)" = 19 ] || die "ubi0 is not mtd19"
grep -q '^mtd19: 02a00000 00020000 "rootfs"$' /proc/mtd || die "mtd19 layout"
[ "$(cat /sys/class/ubi/ubi0_0/name)" = kernel ] || die "vol0 name"
[ "$(cat /sys/class/ubi/ubi0_1/name)" = ubi_rootfs ] || die "vol1 name"
# Stock Xiaomi has only volumes 0 and 1. A previous install of this port
# leaves rootfs_data as volume 2; any other volume 2 is unexpected.
have_vol2=0
if [ -e /sys/class/ubi/ubi0_2 ]; then
	[ "$(cat /sys/class/ubi/ubi0_2/name)" = rootfs_data ] || die "unexpected vol2"
	have_vol2=1
fi
[ ! -e /sys/class/ubi/ubi0_3 ] || die "unexpected vol3"
[ "$(sha256sum "$fit" | cut -d' ' -f1)" = "$fit_sum" ] || die "FIT hash"
[ "$(sha256sum "$sq" | cut -d' ' -f1)" = "$sq_sum" ] || die "squashfs hash"
fit_size=$(wc -c < "$fit"); sq_size=$(wc -c < "$sq")
[ "$fit_size" -le "$(awk '{print $1*126976}' /sys/class/ubi/ubi0_0/reserved_ebs)" ] || die "FIT too big"
[ "$sq_size" -le 16777216 ] || die "squashfs bigger than 16 MiB"
echo "guards ok: ubi0=mtd19 vol2=$have_vol2 fit=$fit_size squashfs=$sq_size"

[ -e /dev/ubiblock0_1 ] && { ubiblock -r /dev/ubi0_1 || die "ubiblock busy"; }
ubiupdatevol /dev/ubi0_0 "$fit" || die "write kernel"
ubiupdatevol /dev/ubi0_1 "$sq" || die "write rootfs"
[ "$(head -c "$fit_size" /dev/ubi0_0 | sha256sum | cut -d' ' -f1)" = "$fit_sum" ] || die "kernel readback"
[ "$(head -c "$sq_size" /dev/ubi0_1 | sha256sum | cut -d' ' -f1)" = "$sq_sum" ] || die "rootfs readback"
echo "readback ok"
# ubi_rootfs keeps 16 MiB (stock: 24.5 MiB, mostly unused by OpenWrt) and
# rootfs_data takes every free LEB.
if [ "$have_vol2" = 1 ]; then
	ubirmvol /dev/ubi0 -n 2 || die "remove vol2"
fi
ubirsvol /dev/ubi0 -n 1 -s 16MiB || die "resize ubi_rootfs"
[ "$(head -c "$sq_size" /dev/ubi0_1 | sha256sum | cut -d' ' -f1)" = "$sq_sum" ] || die "rootfs readback after resize"
ubimkvol /dev/ubi0 -n 2 -N rootfs_data -m || die "create rootfs_data"
ubinfo -d 0 | grep -E 'available|Volumes count'
sync
echo INSTALL_OK
