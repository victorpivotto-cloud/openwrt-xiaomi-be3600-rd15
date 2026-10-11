#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
#
# Prepare an OpenWrt build tree for the Xiaomi BE3600 2.5G (RD15):
#   prepare-tree.sh BUILD_DIR
# Clones fivefold3/openwrt-gl-be3600 into BUILD_DIR (or reuses a clean
# clone there), checks out the pinned BASE_COMMIT, applies the patch for
# files that exist in the base tree, copies the new files and seeds .config
# and feeds.conf (pinned to the feed revisions of the tested build).
# Vendor Wi-Fi files are a separate, local step: scripts/stage-vendor-firmware.sh
set -eu

here=$(cd "$(dirname "$0")/.." && pwd)
dir=${1:?usage: $0 BUILD_DIR}
base_url=https://github.com/fivefold3/openwrt-gl-be3600.git
base=$(cat "$here/BASE_COMMIT")

[ -d "$dir/.git" ] || git clone "$base_url" "$dir"
cd "$dir"
git cat-file -e "$base^{commit}" 2>/dev/null || git fetch origin "$base"
[ -z "$(git status --porcelain --untracked-files=no)" ] ||
	{ echo "$dir has local changes; use a fresh clone" >&2; exit 1; }
git checkout -q --detach "$base"

for p in "$here"/patches/*.patch; do
	git apply --check "$p" || { echo "patch does not apply: $p" >&2; exit 1; }
	git apply "$p"
	echo "applied $(basename "$p")"
done
cp -R "$here/openwrt-tree/." .
cp "$here/configs/xiaomi_rd15.diffconfig" .config
# Feed revisions of the tested build (feeds.buildinfo of that build).
cp "$here/configs/feeds.conf" feeds.conf
echo "tree ready at $dir (base $base); next: stage vendor firmware, then"
echo "  ./scripts/feeds update -a && ./scripts/feeds install -a && make defconfig && make -j\$(nproc)"
