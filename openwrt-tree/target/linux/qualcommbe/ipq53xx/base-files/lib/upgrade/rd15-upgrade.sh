# Xiaomi BE3600 RD15 (xiaomi,rd15): sysupgrade of slot 0 with the fixed stock
# layout on mtd "rootfs" (ubi0):
#   ubi0_0 kernel      static   83 LEBs  <- FIT
#   ubi0_1 ubi_rootfs  dynamic 133 LEBs  <- squashfs
#   ubi0_2 rootfs_data dynamic  96 LEBs  <- emptied, config restored
# Volumes are rewritten in place, never removed, recreated or resized.
# rootfs_1 (Xiaomi), ART, bootloaders and the U-Boot env are never written;
# the boot flags are only read.
#
# rd15_verify_image <img>  read-only preflight (platform_check_image)
# rd15_do_upgrade <img>    stage2 writer (platform_do_upgrade)
#
# The checks are structural, board and FIT hash (integrity) checks, not
# authenticity checks.
# Sourced from /lib/upgrade: defines functions and variables only.

# RAMFS path and slot-selection fallback tested on RD15, 2026-10-18.
# Write barrier is fixed at build time, never read from the environment.
RD15_UPGRADE_ENABLED=1

RD15_BOARD=xiaomi,rd15
RD15_DIR=sysupgrade-xiaomi_rd15
RD15_FIT_CONFIG=config@mi04.1-c2
RD15_LEB=126976
RD15_KERNEL_LEBS=83
RD15_ROOT_LEBS=133
RD15_DATA_LEBS=96
RD15_MTD_SIZE=02a00000
RD15_MTD_ERASE=00020000

# Overridable for the mock tests only.
RD15_SYS="${RD15_SYS:-/sys/class/ubi}"
RD15_PROC="${RD15_PROC:-/proc}"
RD15_DEV="${RD15_DEV:-/dev}"
RD15_BLOCK_SYS="${RD15_BLOCK_SYS:-/sys/class/block}"
RD15_TMP="${RD15_TMP:-/tmp}"
# Seconds to wait for the kernel to drop ubiblock0_1 after ubiblock -r.
RD15_BLOCK_WAIT=5
RD15_TOKEN="$RD15_TMP/rd15-upgrade.verified"

rd15_fail() { echo "rd15: $*" >&2; return 1; }
rd15_cat() { cat "$1" 2>/dev/null; }

rd15_need() {
	local c
	for c in "$@"; do
		command -v "$c" >/dev/null 2>&1 || { rd15_fail "missing tool: $c"; return 1; }
	done
}

# <file> <offset> <count>: the bytes as lowercase hex
rd15_hex() {
	dd if="$1" bs=1 skip="$2" count="$3" 2>/dev/null | hexdump -v -e '1/1 "%02x"'
}

# <file> <512-byte block>: one tar block as hex
rd15_blk() {
	dd if="$1" bs=512 skip="$2" count=1 2>/dev/null | hexdump -v -e '1/1 "%02x"'
}

rd15_strhex() { printf '%s' "$1" | hexdump -v -e '1/1 "%02x"'; }

# <hex>: hex of the leading NUL-terminated string, without the NUL
rd15_hcstr() {
	local h="$1" i=0
	while [ "$i" -lt "${#h}" ]; do
		[ "${h:$i:2}" = 00 ] && { echo "${h:0:$i}"; return 0; }
		i=$((i + 2))
	done
	return 1
}

rd15_cstr() {  # <file> <offset> <max>
	local h
	h=$(rd15_hex "$1" "$2" "$3")
	rd15_hcstr "$h"
}

# <hex> <byte offset> <bytes>: little-endian field as big-endian hex
rd15_le() {
	local h="$1" i=$(($2 + $3 - 1)) r=
	while [ "$i" -ge "$2" ]; do
		r="$r${h:$((i * 2)):2}"
		i=$((i - 1))
	done
	echo "$r"
}

# <hex of an ASCII octal tar field>: decimal
rd15_hoct() {
	local h="$1" i=0 c d=
	while [ "$i" -lt "${#h}" ]; do
		c="${h:$i:2}"
		case "$c" in
		3[0-7]) d="$d${c#3}" ;;
		00|20) [ -n "$d" ] && break ;;
		*) return 1 ;;
		esac
		i=$((i + 2))
	done
	[ -n "$d" ] || return 1
	echo $((0$d))
}

rd15_tar_sum() {  # <header hex>: unsigned header checksum
	local h="$1" i=0 s=0
	while [ "$i" -lt 512 ]; do
		if [ "$i" -ge 148 ] && [ "$i" -lt 156 ]; then
			s=$((s + 32))
		else
			s=$((s + 0x${h:$((i * 2)):2}))
		fi
		i=$((i + 1))
	done
	echo "$s"
}

# <name>: "<index> <size> <erasesize>" of the one MTD with exactly that name
rd15_mtd() {
	awk -v n="\"$1\"" '$4 == n { c++; i = $1; s = $2; e = $3 }
		END { if (c != 1) exit 1; sub(/^mtd/, "", i); sub(/:$/, "", i); print i, s, e }' \
		"$RD15_PROC/mtd" 2>/dev/null
}

rd15_check_vol() {  # <id> <name> <type> <lebs>
	local d="$RD15_SYS/ubi0_$1"

	[ "$(rd15_cat "$d/name")" = "$2" ] &&
	[ "$(rd15_cat "$d/type")" = "$3" ] &&
	[ "$(rd15_cat "$d/reserved_ebs")" = "$4" ] &&
	[ "$(rd15_cat "$d/usable_eb_size")" = "$RD15_LEB" ] ||
		{ rd15_fail "ubi0_$1 is not $2 ($3, $4 LEBs)"; return 1; }
}

rd15_check_layout() {
	local m root

	m=$(rd15_mtd rootfs) || { rd15_fail "no unique MTD named rootfs"; return 1; }
	set -- $m
	[ "$2" = "$RD15_MTD_SIZE" ] && [ "$3" = "$RD15_MTD_ERASE" ] ||
		{ rd15_fail "mtd rootfs is $2/$3, expected $RD15_MTD_SIZE/$RD15_MTD_ERASE"; return 1; }
	root="$1"
	m=$(rd15_mtd rootfs_1) || { rd15_fail "no unique MTD named rootfs_1 (stock slot)"; return 1; }
	set -- $m
	[ "$1" != "$root" ] || { rd15_fail "rootfs and rootfs_1 are the same MTD"; return 1; }
	[ "$(rd15_cat "$RD15_SYS/ubi0/mtd_num")" = "$root" ] ||
		{ rd15_fail "ubi0 is not attached to mtd rootfs"; return 1; }
	[ "$(rd15_cat "$RD15_SYS/ubi0/volumes_count")" = 3 ] && [ ! -e "$RD15_SYS/ubi0_3" ] ||
		{ rd15_fail "ubi0 does not have exactly 3 volumes"; return 1; }
	rd15_check_vol 0 kernel static "$RD15_KERNEL_LEBS" &&
	rd15_check_vol 1 ubi_rootfs dynamic "$RD15_ROOT_LEBS" &&
	rd15_check_vol 2 rootfs_data dynamic "$RD15_DATA_LEBS"
}

# Same env config and CRC test as rd15-slot. Only reads the flags: slot 0
# must be the one bootmiwifi boots and must already be marked good.
rd15_check_env() {
	local m kv cfg="$RD15_TMP/rd15-fw_env.config" err="$RD15_TMP/rd15-env.err"

	m=$(rd15_mtd 0:appsblenv) || { rd15_fail "0:appsblenv not found"; return 1; }
	set -- $m
	echo "$RD15_DEV/mtd$1 0x0 0x10000 0x20000" > "$cfg" ||
		{ rd15_fail "cannot write $cfg"; return 1; }
	fw_printenv -c "$cfg" flag_boot_rootfs >/dev/null 2>"$err" ||
		{ rd15_fail "env unreadable"; return 1; }
	grep -qi 'bad crc' "$err" && { rd15_fail "env CRC bad"; return 1; }
	for kv in flag_boot_rootfs=0 flag_boot_success=1 \
		  flag_try_sys1_failed=0 flag_try_sys2_failed=0; do
		[ "$(fw_printenv -c "$cfg" -n "${kv%%=*}" 2>/dev/null)" = "${kv#*=}" ] ||
			{ rd15_fail "slot 0 not marked good ($kv expected, see rd15-slot status)"; return 1; }
	done
}

rd15_check_slot() {
	local cl

	[ "$(rd15_cat "$RD15_TMP/sysinfo/board_name")" = "$RD15_BOARD" ] ||
		{ rd15_fail "not a Xiaomi RD15"; return 1; }
	cl=" $(rd15_cat "$RD15_PROC/cmdline") "
	case "$cl" in
	*" ubi.mtd=rootfs_1 "*) rd15_fail "booted from rootfs_1"; return 1 ;;
	*" ubi.mtd=rootfs "*) ;;
	*) rd15_fail "not booted from slot 0 (ubi.mtd=rootfs)"; return 1 ;;
	esac
	rd15_check_layout && rd15_check_env
}

# Parse the tar headers ourselves: exactly the directory followed by CONTROL,
# kernel and root (any order), each once, plain ustar/gnu headers with a good
# checksum, then the end-of-archive blocks. tar(1) must list the same names.
# Sets RD15_{C,K,R}_{OFF,SIZE} (data offset/size in the image file).
rd15_tar_scan() {
	local f="$1" off=0 n=0 h nm typ sz ck list l
	local hd hc hk hr

	hd=$(rd15_strhex "$RD15_DIR/")
	hc=$(rd15_strhex "$RD15_DIR/CONTROL")
	hk=$(rd15_strhex "$RD15_DIR/kernel")
	hr=$(rd15_strhex "$RD15_DIR/root")
	RD15_C_OFF= RD15_K_OFF= RD15_R_OFF=
	RD15_C_SIZE= RD15_K_SIZE= RD15_R_SIZE=

	while :; do
		h=$(rd15_blk "$f" $((off / 512)))
		[ "${#h}" = 1024 ] || { rd15_fail "tar truncated"; return 1; }
		case "$h" in *[!0]*) ;; *) break ;; esac
		n=$((n + 1))
		[ "$n" -le 4 ] || { rd15_fail "unexpected extra tar member"; return 1; }
		[ "${h:514:10}" = 7573746172 ] || { rd15_fail "not a sysupgrade tar"; return 1; }
		ck=$(rd15_hoct "${h:296:16}") && [ "$ck" = "$(rd15_tar_sum "$h")" ] ||
			{ rd15_fail "tar header checksum"; return 1; }
		nm=$(rd15_hcstr "${h:0:200}") || { rd15_fail "tar member name"; return 1; }
		sz=$(rd15_hoct "${h:248:24}") || { rd15_fail "tar member size"; return 1; }
		typ="${h:312:2}"

		case "$nm" in
		"$hd")
			[ "$n" = 1 ] && [ "$typ" = 35 ] && [ "$sz" = 0 ] ||
				{ rd15_fail "bad $RD15_DIR/ entry"; return 1; }
			list="$RD15_DIR/"
			;;
		"$hc"|"$hk"|"$hr")
			[ "$n" -gt 1 ] && { [ "$typ" = 30 ] || [ "$typ" = 00 ]; } ||
				{ rd15_fail "tar member is not a regular file in $RD15_DIR/"; return 1; }
			[ "$sz" -gt 0 ] || { rd15_fail "empty tar member"; return 1; }
			case "$nm" in
			"$hc")
				[ -z "$RD15_C_OFF" ] || { rd15_fail "duplicate CONTROL"; return 1; }
				RD15_C_OFF=$((off + 512)) RD15_C_SIZE="$sz"
				l=CONTROL
				;;
			"$hk")
				[ -z "$RD15_K_OFF" ] || { rd15_fail "duplicate kernel"; return 1; }
				RD15_K_OFF=$((off + 512)) RD15_K_SIZE="$sz"
				l=kernel
				;;
			*)
				[ -z "$RD15_R_OFF" ] || { rd15_fail "duplicate root"; return 1; }
				RD15_R_OFF=$((off + 512)) RD15_R_SIZE="$sz"
				l=root
				;;
			esac
			list="$list
$RD15_DIR/$l"
			;;
		*)
			rd15_fail "unexpected tar member (not a $RD15_DIR sysupgrade image?)"
			return 1
			;;
		esac
		off=$((off + 512 + (sz + 511) / 512 * 512))
	done

	[ "$n" = 4 ] || { rd15_fail "tar must hold $RD15_DIR/{CONTROL,kernel,root}"; return 1; }
	h=$(rd15_blk "$f" $((off / 512 + 1)))
	[ "${#h}" = 1024 ] || { rd15_fail "tar truncated"; return 1; }
	case "$h" in *[!0]*) rd15_fail "bad end of tar archive"; return 1 ;; esac
	l=$(tar tf "$f" 2>/dev/null) && [ "$l" = "$list" ] ||
		{ rd15_fail "tar listing disagrees with the headers"; return 1; }
}

# CONTROL is "BOARD=<image profile>" (23 bytes "BOARD=glinet_gl-be3600\n"
# measured on the GL image, see platform.sh).
rd15_check_control() {
	local c

	[ "$RD15_C_SIZE" -le 4096 ] || { rd15_fail "CONTROL too big"; return 1; }
	c=$(tar xOf "$1" "$RD15_DIR/CONTROL" 2>/dev/null) || { rd15_fail "cannot read CONTROL"; return 1; }
	[ "$(printf '%s\n' "$c" | grep -c '^BOARD=')" = 1 ] &&
	printf '%s\n' "$c" | grep -qx 'BOARD=xiaomi_rd15' ||
		{ rd15_fail "CONTROL is not for xiaomi_rd15"; return 1; }
}

# <file> <offset> exact|max <len>: FDT header sanity; sets RD15_FDT_*.
rd15_fdt_header() {
	local h t rsv ver last

	h=$(rd15_hex "$1" "$2" 40)
	[ "${#h}" = 80 ] && [ "${h:0:8}" = d00dfeed ] || return 1
	t=$((0x${h:8:8}))
	RD15_FDT_SOFF=$((0x${h:16:8}))
	RD15_FDT_STROFF=$((0x${h:24:8}))
	rsv=$((0x${h:32:8}))
	ver=$((0x${h:40:8}))
	last=$((0x${h:48:8}))
	RD15_FDT_STRSZ=$((0x${h:64:8}))
	RD15_FDT_SSZ=$((0x${h:72:8}))
	case "$3" in
	exact) [ "$t" = "$4" ] || return 1 ;;
	*) [ "$t" -le "$4" ] || return 1 ;;
	esac
	[ "$ver" = 17 ] && [ "$last" = 16 ] &&
	[ "$rsv" -ge 40 ] && [ $((rsv % 8)) = 0 ] &&
	[ $((RD15_FDT_SOFF % 4)) = 0 ] && [ "$RD15_FDT_SOFF" -ge $((rsv + 16)) ] &&
	[ "$RD15_FDT_SSZ" -ge 8 ] && [ $((RD15_FDT_SOFF + RD15_FDT_SSZ)) -le "$t" ] &&
	[ $((RD15_FDT_STROFF + RD15_FDT_STRSZ)) -le "$t" ]
}

# <file> <fdt offset> <rootonly 0|1>: walk the structure block (bounded,
# with lseek over large values) using RD15_FDT_* and print
#   N <depth> <name hex>               node (root is depth 0)
#   P <owner depth> <name hex> <len> <value offset> <value hex, "-" if >128 B>
#   E <depth>                          end of node
#   END
# rootonly stops after the root node's own properties.
rd15_fdt_walk() {
	local f="$1" base="$2" p e depth=0 n=0 rs= h tok nm len noff v

	p=$((base + RD15_FDT_SOFF))
	e=$((p + RD15_FDT_SSZ))
	while [ "$p" -lt "$e" ]; do
		n=$((n + 1))
		[ "$n" -le 2048 ] || return 1
		h=$(rd15_hex "$f" "$p" 12)
		[ "${#h}" -ge 8 ] || return 1
		tok=$((0x${h:0:8}))
		case "$tok" in
		1)
			[ "$3" = 1 ] && [ "$depth" = 1 ] && { echo END; return 0; }
			nm=$(rd15_cstr "$f" $((p + 4)) 64) || return 1
			if [ "$depth" = 0 ]; then
				[ -z "$rs" ] && [ -z "$nm" ] || return 1
				rs=1
			else
				[ -n "$nm" ] || return 1
			fi
			echo "N $depth $nm"
			depth=$((depth + 1))
			p=$((p + 4 + (${#nm} / 2 + 4) / 4 * 4))
			;;
		2)
			[ "$depth" -gt 0 ] || return 1
			depth=$((depth - 1))
			echo "E $depth"
			[ "$3" = 1 ] && [ "$depth" = 0 ] && { echo END; return 0; }
			p=$((p + 4))
			;;
		3)
			[ "$depth" -gt 0 ] && [ "${#h}" = 24 ] || return 1
			len=$((0x${h:8:8}))
			noff=$((0x${h:16:8}))
			[ "$noff" -lt "$RD15_FDT_STRSZ" ] && [ $((p + 12 + len)) -le "$e" ] || return 1
			nm=$(rd15_cstr "$f" $((base + RD15_FDT_STROFF + noff)) 64) || return 1
			v=-
			[ "$len" -le 128 ] && v=$(rd15_hex "$f" $((p + 12)) "$len")
			echo "P $((depth - 1)) $nm $len $((p + 12)) $v"
			p=$((p + 12 + (len + 3) / 4 * 4))
			;;
		4)
			p=$((p + 4))
			;;
		9)
			[ "$depth" = 0 ] && [ -n "$rs" ] || return 1
			echo END
			return 0
			;;
		*)
			return 1
			;;
		esac
	done
	return 1
}

# <images list> <name hex>: "type comp len off" of the one image of that name
rd15_fit_image() {
	local e r= c=0

	for e in $1; do
		[ "${e%%:*}" = "$2" ] || continue
		c=$((c + 1))
		r="${e#*:}"
	done
	[ "$c" = 1 ] || return 1
	echo "${r//:/ }"
}

# <value hex>: hex of the value as a single NUL-terminated string
rd15_fdt_str() {
	local s
	s=$(rd15_hcstr "$1") && [ -n "$s" ] && [ "${s}00" = "$1" ] && echo "$s"
}

# <image> <data offset> <data len> <hash list> <label>: integrity of one FIT
# image's data (not authenticity). The list is "+algo=value" per hash-* node
# (hex, "-" if absent, "!" if a property is repeated). crc32 and unknown algos
# are ignored; at least one sha1/sha256 is required, each at most once, and
# every one must match the exact data bytes (streamed, never copied whole).
rd15_fit_hash() {
	local f="$1" o="$2" l="$3" hl="$4" e a v n tool s seen=

	for e in ${hl//+/ }; do
		[ "$e" = - ] && continue
		a=$(rd15_fdt_str "${e%%=*}") || { rd15_fail "FIT $5 has a malformed hash node"; return 1; }
		v="${e#*=}"
		case "$a" in  # rd15_fdt_str gives hex: "sha1", "sha256"
		73686131) a=sha1 tool=sha1sum n=40 ;;
		736861323536) a=sha256 tool=sha256sum n=64 ;;
		*) continue ;;
		esac
		case "$seen " in *" $a "*) rd15_fail "FIT $5 has more than one $a hash (ambiguous)"; return 1 ;; esac
		seen="$seen $a"
		[ "${#v}" = "$n" ] || { rd15_fail "FIT $5 $a hash value malformed"; return 1; }
		s=$(tail -c +$((o + 1)) "$f" 2>/dev/null | head -c "$l" | $tool)
		[ "${s%% *}" = "$v" ] || { rd15_fail "FIT $5 $a hash mismatch (data corrupt)"; return 1; }
	done
	[ -n "$seen" ] || { rd15_fail "FIT $5 has no sha1/sha256 hash"; return 1; }
}

# The kernel member is a FIT with embedded data (totalsize == member size)
# whose /configurations/config@mi04.1-c2 points at an lzma "kernel" image and
# a "flat_dt" image; that DTB's first compatible must be xiaomi,rd15. The data
# of both images must match their hash-* nodes (rd15_fit_hash).
rd15_check_fit() {  # <image> <member offset> <member size>
	local f="$1" o="$2" sz="$3" w="$RD15_TMP/rd15-fit.walk"
	local t d nm ln vo vh n1= n2= ityp= icomp= ilen= ioff= imgs= kref= fref= cfg=0
	local ihash= inh= halgo= hval= ha= hv= hd=
	local H_IMAGES H_CONFS H_CFG H_TYPE H_COMP H_DATA H_KERNEL H_FDT
	local H_HASH H_ALGO H_VALUE
	local kname fname klen koff khash doff dlen dhash compat

	[ "$sz" -ge 40 ] && rd15_fdt_header "$f" "$o" exact "$sz" ||
		{ rd15_fail "kernel is not a well-formed FIT (header/totalsize)"; return 1; }
	rd15_fdt_walk "$f" "$o" 0 > "$w" && [ "$(tail -n 1 "$w" 2>/dev/null)" = END ] ||
		{ rm -f "$w"; rd15_fail "FIT structure block invalid"; return 1; }

	H_IMAGES=$(rd15_strhex images)
	H_CONFS=$(rd15_strhex configurations)
	H_CFG=$(rd15_strhex "$RD15_FIT_CONFIG")
	H_TYPE=$(rd15_strhex type)
	H_COMP=$(rd15_strhex compression)
	H_DATA=$(rd15_strhex data)
	H_KERNEL=$(rd15_strhex kernel)
	H_FDT=$(rd15_strhex fdt)
	H_HASH=$(rd15_strhex hash)
	H_ALGO=$(rd15_strhex algo)
	H_VALUE=$(rd15_strhex value)

	while read -r t d nm ln vo vh; do
		case "$t" in
		N)
			[ "$d" = 1 ] && n1="$nm"
			if [ "$d" = 2 ]; then
				n2="$nm" ityp= icomp= ilen= ioff= ihash= inh=
				[ "$n1" = "$H_CONFS" ] && [ "$nm" = "$H_CFG" ] && cfg=$((cfg + 1))
			fi
			if [ "$d" = 3 ] && [ "$n1" = "$H_IMAGES" ]; then
				# same prefix test as U-Boot: hash-1, hash@1, ...
				case "$nm" in
				"$H_HASH"*) inh=1 halgo= hval= ha= hv= hd= ;;
				*) inh= ;;
				esac
			fi
			;;
		P)
			if [ "$d" = 3 ] && [ -n "$inh" ]; then
				case "$nm" in
				"$H_ALGO") [ -n "$ha" ] && hd=1; ha=1 halgo="$vh" ;;
				"$H_VALUE") [ -n "$hv" ] && hd=1; hv=1 hval="$vh" ;;
				esac
				continue
			fi
			[ "$d" = 2 ] || continue
			if [ "$n1" = "$H_IMAGES" ]; then
				case "$nm" in
				"$H_TYPE") ityp="$vh" ;;
				"$H_COMP") icomp="$vh" ;;
				"$H_DATA") [ -z "$ilen" ] && ilen="$ln" ioff="$vo" || ilen=-1 ;;  # repeated: refused
				esac
			elif [ "$n1" = "$H_CONFS" ] && [ "$n2" = "$H_CFG" ]; then
				case "$nm" in
				"$H_KERNEL") kref="$vh" ;;
				"$H_FDT") fref="$vh" ;;
				esac
			fi
			;;
		E)
			if [ "$d" = 3 ] && [ -n "$inh" ]; then
				[ -n "$hd" ] && halgo=!
				ihash="$ihash+${halgo:--}=${hval:--}"
				inh=
			fi
			[ "$d" = 2 ] && [ "$n1" = "$H_IMAGES" ] &&
				imgs="$imgs $n2:${ityp:--}:${icomp:--}:${ilen:-0}:${ioff:-0}:${ihash:--}"
			;;
		esac
	done < "$w"
	rm -f "$w"

	[ "$cfg" = 1 ] || { rd15_fail "FIT has no single /configurations/$RD15_FIT_CONFIG"; return 1; }
	kname=$(rd15_fdt_str "$kref") && fname=$(rd15_fdt_str "$fref") ||
		{ rd15_fail "$RD15_FIT_CONFIG lacks kernel/fdt"; return 1; }

	set -- $(rd15_fit_image "$imgs" "$kname")
	[ "$1" = "${H_KERNEL}00" ] && [ "$2" = "$(rd15_strhex lzma)00" ] && [ "${3:-0}" -gt 0 ] ||
		{ rd15_fail "FIT kernel image missing, not type kernel or not lzma"; return 1; }
	klen="$3" koff="$4" khash="$5"

	set -- $(rd15_fit_image "$imgs" "$fname")
	[ "$1" = "$(rd15_strhex flat_dt)00" ] && [ "$2" = "$(rd15_strhex none)00" ] &&
	[ "${3:-0}" -ge 40 ] ||
		{ rd15_fail "FIT fdt image missing, not flat_dt or compressed"; return 1; }
	dlen="$3" doff="$4" dhash="$5"

	rd15_fdt_header "$f" "$doff" max "$dlen" ||
		{ rd15_fail "FIT fdt is not a well-formed DTB"; return 1; }
	rd15_fdt_walk "$f" "$doff" 1 > "$w" && [ "$(tail -n 1 "$w" 2>/dev/null)" = END ] ||
		{ rm -f "$w"; rd15_fail "DTB structure block invalid"; return 1; }
	compat=$(awk -v c="$(rd15_strhex compatible)" '$1 == "P" && $2 == 0 && $3 == c { print $6 }' "$w")
	rm -f "$w"
	case "$compat" in
	"$(rd15_strhex "$RD15_BOARD")00"*) ;;
	*) rd15_fail "DTB in $RD15_FIT_CONFIG is not compatible $RD15_BOARD"; return 1 ;;
	esac
	rd15_fit_hash "$f" "$koff" "$klen" "$khash" kernel &&
	rd15_fit_hash "$f" "$doff" "$dlen" "$dhash" fdt
}

# squashfs 4.0 superblock: sizes and table offsets inside the member.
rd15_check_squashfs() {  # <image> <member offset> <member size>
	local sb bl x used o

	[ "$3" -ge 96 ] && sb=$(rd15_hex "$1" "$2" 96) &&
	[ "${#sb}" = 192 ] && [ "${sb:0:8}" = 68737173 ] ||
		{ rd15_fail "root is not squashfs"; return 1; }
	[ "$(rd15_le "$sb" 28 2)" = 0004 ] && [ "$(rd15_le "$sb" 30 2)" = 0000 ] ||
		{ rd15_fail "root is not squashfs 4.0"; return 1; }
	bl=$((0x$(rd15_le "$sb" 22 2)))
	[ "$bl" -ge 12 ] && [ "$bl" -le 20 ] &&
	[ $((0x$(rd15_le "$sb" 12 4))) = $((1 << bl)) ] ||
		{ rd15_fail "squashfs block size invalid"; return 1; }
	x=$((0x$(rd15_le "$sb" 20 2)))
	[ "$x" -ge 1 ] && [ "$x" -le 6 ] || { rd15_fail "squashfs compression invalid"; return 1; }
	[ $((0x$(rd15_le "$sb" 4 4))) -gt 0 ] || { rd15_fail "squashfs has no inodes"; return 1; }
	x=$(rd15_le "$sb" 40 8)
	case "$x" in [89a-f]*) rd15_fail "squashfs bytes_used invalid"; return 1 ;; esac
	used=$((0x$x))
	[ "$used" -gt 96 ] && [ "$used" -le "$3" ] ||
		{ rd15_fail "squashfs bytes_used $used outside member ($3 B): truncated?"; return 1; }
	for o in 48 64 72; do  # id, inode and directory tables
		x=$(rd15_le "$sb" "$o" 8)
		case "$x" in [89a-f]*) rd15_fail "squashfs table offset invalid"; return 1 ;; esac
		[ $((0x$x)) -ge 96 ] && [ $((0x$x)) -lt "$used" ] ||
			{ rd15_fail "squashfs table offset outside image"; return 1; }
	done
}

# Read-only checks shared by preflight and stage2.
rd15_verify_common() {  # <image>
	local img="$1" n

	[ -f "$img" ] || { rd15_fail "image not found"; return 1; }
	case "$(rd15_hex "$img" 0 4)" in
	d00dfeed) rd15_fail "FIT (factory?) image: use the sysupgrade tar"; return 1 ;;
	55424923) rd15_fail "UBI image: use the sysupgrade tar"; return 1 ;;
	1f8b*) rd15_fail "compressed image: use the sysupgrade tar"; return 1 ;;
	esac
	rd15_check_slot || return 1
	rd15_tar_scan "$img" || return 1
	rd15_check_control "$img" || return 1
	[ "$RD15_K_SIZE" -le $((RD15_KERNEL_LEBS * RD15_LEB)) ] ||
		{ rd15_fail "kernel $RD15_K_SIZE B > $RD15_KERNEL_LEBS LEBs"; return 1; }
	[ "$RD15_R_SIZE" -le $((RD15_ROOT_LEBS * RD15_LEB)) ] ||
		{ rd15_fail "root $RD15_R_SIZE B > $RD15_ROOT_LEBS LEBs"; return 1; }
	rd15_check_fit "$img" "$RD15_K_OFF" "$RD15_K_SIZE" || return 1
	rd15_check_squashfs "$img" "$RD15_R_OFF" "$RD15_R_SIZE" || return 1
	# The writer streams through tar: it must yield the same lengths.
	n=$(tar xOf "$img" "$RD15_DIR/kernel" 2>/dev/null | wc -c)
	[ "$((n))" = "$RD15_K_SIZE" ] || { rd15_fail "kernel unreadable through tar"; return 1; }
	n=$(tar xOf "$img" "$RD15_DIR/root" 2>/dev/null | wc -c)
	[ "$((n))" = "$RD15_R_SIZE" ] || { rd15_fail "root unreadable through tar"; return 1; }
}

rd15_image_id() {  # <image>: "<sha256> <size>"
	local s n

	s=$(sha256sum < "$1" 2>/dev/null) || return 1
	s="${s%% *}"
	n=$(wc -c < "$1") || return 1
	[ "${#s}" = 64 ] || return 1
	echo "$s $((n))"
}

rd15_member_sum() {  # <image> <member>
	local s

	s=$(tar xOf "$1" "$RD15_DIR/$2" 2>/dev/null | sha256sum)
	s="${s%% *}"
	[ "${#s}" = 64 ] && echo "$s"
}

# Preflight (platform_check_image). Read-only for flash and env. On success
# it records the image hash; stage2 refuses any image without that record,
# so "sysupgrade -F" / LuCI "Force" cannot skip these checks.
rd15_verify_image() {  # <image>
	local img="$1" id

	rm -f "$RD15_TOKEN"
	[ "$#" = 1 ] || return 1
	rd15_need tar dd hexdump tail head wc awk grep sha1sum sha256sum fw_printenv || return 1
	type fwtool_check_image >/dev/null 2>&1 ||
		{ rd15_fail "fwtool_check_image unavailable"; return 1; }
	fwtool_check_image "$img" ||
		{ rd15_fail "image metadata missing or not for $RD15_BOARD"; return 1; }
	rd15_verify_common "$img" || return 1
	id=$(rd15_image_id "$img") || { rd15_fail "cannot hash image"; return 1; }
	echo "$RD15_BOARD $id" > "$RD15_TOKEN.new" && mv "$RD15_TOKEN.new" "$RD15_TOKEN" ||
		{ rm -f "$RD15_TOKEN.new"; rd15_fail "cannot record verification"; return 1; }
	echo "rd15: image passed structure/board/FIT hash checks (integrity, not authenticity)"
}

rd15_check_unmounted() {
	local dev mp fs rest

	[ -r "$RD15_PROC/mounts" ] || { rd15_fail "cannot read mounts"; return 1; }
	while read -r dev mp fs rest; do
		case "$dev" in
		/dev/ubi0|/dev/ubi0_*|/dev/ubiblock0_*|ubi0:*|ubi0_*)
			rd15_fail "$dev still mounted on $mp"; return 1 ;;
		esac
		case "$mp" in
		/overlay|/rom)
			rd15_fail "$mp still mounted"; return 1 ;;
		/)
			case "$fs" in
			squashfs|overlay|ubifs) rd15_fail "root filesystem still on flash ($fs)"; return 1 ;;
			esac
			;;
		esac
	done < "$RD15_PROC/mounts"
}

rd15_block_present() {
	[ -e "$RD15_BLOCK_SYS/ubiblock0_1" ] || [ -L "$RD15_BLOCK_SYS/ubiblock0_1" ]
}

# Remove ubiblock0_1 on ubi0_1. The kernel (sysfs) decides: in stage2 udev and
# hotplug are gone, so /dev/ubiblock0_1 can stay behind as a stale node after
# a successful ubiblock -r (seen on hardware). A stale node is not refused; a
# sysfs entry still there after RD15_BLOCK_WAIT seconds is.
rd15_release_block() {
	local i=0 rc=0

	[ -d "$RD15_BLOCK_SYS" ] && [ -r "$RD15_BLOCK_SYS" ] && [ -x "$RD15_BLOCK_SYS" ] ||
		{ rd15_fail "block sysfs directory unavailable: $RD15_BLOCK_SYS"; return 1; }

	if [ -e "$RD15_DEV/ubiblock0_1" ] || rd15_block_present; then
		ubiblock -r "$RD15_DEV/ubi0_1" || rc=$?
	fi
	while rd15_block_present; do
		[ "$i" -lt "$RD15_BLOCK_WAIT" ] ||
			{ rd15_fail "ubiblock0_1 still in $RD15_BLOCK_SYS after ubiblock -r (rc $rc)"; return 1; }
		sleep 1
		i=$((i + 1))
	done
	[ "$rc" = 0 ] || echo "rd15: ubiblock -r returned $rc, but ubiblock0_1 is gone from $RD15_BLOCK_SYS"
	[ ! -e "$RD15_DEV/ubiblock0_1" ] ||
		echo "rd15: stale $RD15_DEV/ubiblock0_1 node left (no udev in stage2), kernel device is gone"
	rd15_check_unmounted
}

rd15_write() {  # <image> <vol id> <member> <size> <sha256>
	local dev="$RD15_DEV/ubi0_$2" d="$RD15_SYS/ubi0_$2" s

	tar xOf "$1" "$RD15_DIR/$3" | ubiupdatevol "$dev" -s "$4" - ||
		{ rd15_fail "writing $3 to ubi0_$2 failed"; return 1; }
	[ "$(rd15_cat "$d/upd_marker")" = 0 ] ||
		{ rd15_fail "ubi0_$2 update marker still set"; return 1; }
	if [ "$(rd15_cat "$d/type")" = static ]; then
		[ "$(rd15_cat "$d/data_bytes")" = "$4" ] && [ "$(rd15_cat "$d/corrupted")" = 0 ] ||
			{ rd15_fail "ubi0_$2 static volume size/CRC wrong after write"; return 1; }
	fi
	s=$(head -c "$4" "$dev" | sha256sum)
	[ "${s%% *}" = "$5" ] || { rd15_fail "ubi0_$2 readback mismatch"; return 1; }
}

# Stage2 (platform_do_upgrade), running from the ramfs. Repeats every
# read-only check, then writes root, kernel, empties rootfs_data and puts the
# saved config back through the existing NAND path (nand_restore_config).
rd15_do_upgrade() {  # <image>
	local img="$1" ksum rsum n

	rd15_need tar dd hexdump tail wc awk grep sha1sum sha256sum head gzip fw_printenv \
		ubiupdatevol ubiblock sleep || return 1
	rd15_verify_common "$img" || return 1
	[ "$(rd15_cat "$RD15_TOKEN")" = "$RD15_BOARD $(rd15_image_id "$img")" ] ||
		{ rd15_fail "image not accepted by rd15_verify_image (forced?), refusing"; return 1; }
	if [ -n "$UPGRADE_BACKUP" ]; then
		[ -s "$UPGRADE_BACKUP" ] && gzip -t "$UPGRADE_BACKUP" 2>/dev/null ||
			{ rd15_fail "config backup $UPGRADE_BACKUP missing or corrupt"; return 1; }
		n=$(wc -c < "$UPGRADE_BACKUP")
		[ "$((n))" -le $((RD15_DATA_LEBS * RD15_LEB / 2)) ] ||
			{ rd15_fail "config backup too big for rootfs_data"; return 1; }
		type nand_restore_config >/dev/null 2>&1 &&
		grep -qw ubifs "$RD15_PROC/filesystems" 2>/dev/null ||
			{ rd15_fail "config backup cannot be restored (no ubifs/nand_restore_config)"; return 1; }
	fi
	rd15_check_unmounted || return 1

	[ "$RD15_UPGRADE_ENABLED" = 1 ] ||
		{ rd15_fail "flash writing disabled in this build (RD15_UPGRADE_ENABLED=0), nothing written"; return 1; }

	ksum=$(rd15_member_sum "$img" kernel) && rsum=$(rd15_member_sum "$img" root) ||
		{ rd15_fail "cannot hash image members"; return 1; }
	rd15_release_block || { rd15_fail "ubiblock0_1 not released, nothing written"; return 1; }

	# ---- flash writes start here ----
	rd15_write "$img" 1 root "$RD15_R_SIZE" "$rsum" ||
		{ rd15_fail "SLOT 0 ROOT MAY BE DAMAGED"; return 1; }
	rd15_write "$img" 0 kernel "$RD15_K_SIZE" "$ksum" ||
		{ rd15_fail "SLOT 0 INCONSISTENT: new root, kernel write failed"; return 1; }
	ubiupdatevol -t "$RD15_DEV/ubi0_2" ||
		{ rd15_fail "firmware written but old rootfs_data not cleared"; return 1; }
	rd15_check_layout || { rd15_fail "UBI layout changed during upgrade"; return 1; }
	if [ -n "$UPGRADE_BACKUP" ]; then
		CI_UBIPART=rootfs
		nand_restore_config "$UPGRADE_BACKUP" ||
			{ rd15_fail "firmware written, config NOT restored (defaults will boot)"; return 1; }
	fi
	sync
	echo "rd15: slot 0 written and read back"
}
