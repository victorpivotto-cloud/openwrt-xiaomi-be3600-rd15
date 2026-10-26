#!/usr/bin/env python3
"""Inspect a locally built RD15 sysupgrade, offline. Never writes the device.

Checks the fixed tar/layout, metadata, FIT configuration, safe-defaults and
updater source parity, SHA1SUM, management public key, and absence of the
immutable defaults marker. Optional private overlay checks compare blobs
locally; no keys, firmware contents or digests are printed. This does not
replace sysupgrade --test, readback, boot or radio qualification. It does
not verify the compiled kernel driver patch or authenticate image provenance.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import posixpath
import zlib
import subprocess
import sys
import tarfile
import tempfile

REPO = Path(__file__).resolve().parents[1]
PORT = REPO / 'openwrt-tree'
PREFIX = 'sysupgrade-xiaomi_rd15/'
KERNEL_CAP, ROOT_CAP = 10539008, 16887808
SOURCES = {
    'etc/uci-defaults/99-rd15-safe-defaults': PORT / 'files/etc/uci-defaults/99-rd15-safe-defaults',
    'lib/upgrade/rd15-upgrade.sh': PORT / 'target/linux/qualcommbe/ipq53xx/base-files/lib/upgrade/rd15-upgrade.sh',
}
BLOBS = [
    'lib/firmware/ath12k/QCN6432/hw1.0/' + family + suffix
    for family in ['q6_fw2', 'iu_fw']
    for suffix in ['.mdt', '.b00', '.b01', '.b02']
] + [
    'lib/firmware/ath12k/QCN6432/hw1.0/board.bin',
    'lib/firmware/ath12k/IPQ5332/hw1.0/board.bin',
]


class CheckFailure(Exception):
    pass


def parse_fit_listing(text):
    images, configs = {}, {}
    current = None
    for line in text.splitlines():
        match = re.fullmatch(r'\s+Image (\d+) \(([^)]+)\)', line)
        if match:
            index, name = int(match[1]), match[2]
            if index in images or any(image['name'] == name for image in images.values()):
                raise CheckFailure('duplicate_fit_image')
            current = images[index] = {'index': index, 'name': name, 'hashes': []}
            continue
        match = re.fullmatch(r'\s+Configuration \d+ \(([^)]+)\)', line)
        if match:
            if match[1] in configs:
                raise CheckFailure('duplicate_fit_configuration')
            current = configs[match[1]] = {}
            continue
        match = re.fullmatch(r'\s+([^:]+):\s*(.*)', line)
        if not match or current is None:
            continue
        key, value = match[1].strip(), match[2].strip()
        if key == 'Hash algo' and 'hashes' in current:
            current['hashes'].append([value, None])
        elif key == 'Hash value' and 'hashes' in current:
            if not current['hashes'] or current['hashes'][-1][1] is not None:
                raise CheckFailure('invalid_fit_hash_listing')
            current['hashes'][-1][1] = value
        else:
            current[key] = value
    return images, configs


def parse_fs_listing(text):
    entries = {}
    for line in text.splitlines():
        left, separator, right = line.partition(' squashfs-root')
        fields = left.split()
        if not separator or len(fields) != 5 or len(fields[0]) != 10:
            continue
        path, arrow, target = right.partition(' -> ')
        name = path.lstrip('/')
        entries[name] = {'mode': fields[0], 'owner': fields[1], 'target': target if arrow else None}
    return entries


def resolve_fs_entry(entries, path):
    for _ in range(16):
        entry = entries.get(path)
        if entry is None:
            return None
        if entry['mode'][0] != 'l':
            return entry
        target = entry['target']
        if not target:
            return None
        path = posixpath.normpath(target.lstrip('/') if target.startswith('/') else posixpath.join(posixpath.dirname(path), target))
        if path == '..' or path.startswith('../'):
            return None
    return None


def root_owned_not_writable(entry, kind):
    return bool(entry and entry['mode'][0] == kind and entry['owner'].split('/')[0] in ['root', '0'] and entry['mode'][5] != 'w' and entry['mode'][8] != 'w')


def inspect(args):
    result = {'passed': False, 'checks': {}, 'private_overlay_checked': bool(args.overlay)}

    def check(name, condition):
        result['checks'][name] = bool(condition)
        if not condition:
            raise CheckFailure(name)

    def run(argv):
        p = subprocess.run([str(a) for a in argv], capture_output=True, timeout=30)
        if p.returncode:
            raise CheckFailure('inspection_tool_failed')
        return p.stdout

    try:
        check('bounded_image_size', 0 < args.image.stat().st_size <= KERNEL_CAP + ROOT_CAP + 65536)
        with tempfile.TemporaryDirectory(prefix='rd15-image-check-') as tmp:
            temp = Path(tmp)
            with tarfile.open(args.image, 'r:') as tar:
                members = tar.getmembers()
                check('regular_members_only', all((m.type == tarfile.REGTYPE or (m.type == tarfile.DIRTYPE and m.name.rstrip('/') == PREFIX.rstrip('/'))) and not m.pax_headers and m.offset_data - m.offset == 512 for m in members))
                files = [m for m in members if m.isfile()]
                check('exact_tar_members', len(files) == 3 and {m.name for m in files} == {PREFIX + n for n in ['CONTROL', 'kernel', 'root']})
                byname = {m.name: m for m in files}
                check('control_size', 0 < byname[PREFIX + 'CONTROL'].size <= 4096)
                check('control_board', b'BOARD=xiaomi_rd15' in tar.extractfile(byname[PREFIX + 'CONTROL']).read().splitlines())
                for name, cap in [('kernel', KERNEL_CAP), ('root', ROOT_CAP)]:
                    member = byname[PREFIX + name]
                    check(name + '_capacity', 0 < member.size <= cap)
                    (temp / name).write_bytes(tar.extractfile(member).read())
            check('fit_magic', (temp / 'kernel').read_bytes()[:4] == b'\xd0\x0d\xfe\xed')
            check('squashfs_magic', (temp / 'root').read_bytes()[:4] == b'hsqs')
            metadata_file = temp / 'metadata.json'
            run([args.fwtool, '-i', metadata_file, args.image])
            metadata = json.loads(metadata_file.read_text())
            supported = metadata.get('supported_devices')
            check('supported_board', isinstance(supported, list) and all(isinstance(device, str) for device in supported) and 'xiaomi,rd15' in supported)
            check('compat_version', metadata.get('compat_version') == '1.0')
            fit = run([args.dumpimage, '-l', temp / 'kernel']).decode('utf-8', 'replace')
            images, configs = parse_fit_listing(fit)
            config = configs.get('config@mi04.1-c2')
            check('fit_configuration', config is not None)
            check('bounded_fit_images', 1 <= len(images) <= 16)
            by_name = {image['name']: image for image in images.values()}
            check('referenced_kernel_exists', config.get('Kernel') in by_name)
            check('referenced_fdt_exists', config.get('FDT') in by_name)
            kernel_image, dtb_image = by_name[config['Kernel']], by_name[config['FDT']]
            check('fit_kernel_type', kernel_image.get('Type') == 'Kernel Image')
            check('fit_kernel_compression', kernel_image.get('Compression') == 'lzma compressed')
            check('fit_kernel_load', int(kernel_image.get('Load Address', '-1'), 16) == 0x41000000)
            check('fit_kernel_entry', int(kernel_image.get('Entry Point', '-1'), 16) == 0x41000000)
            check('fit_dtb_type', dtb_image.get('Type') == 'Flat Device Tree')
            payloads = {}
            for index, image in images.items():
                output = temp / ('fit-image-' + str(index))
                run([args.dumpimage, '-T', 'flat_dt', '-p', str(index), '-o', output, temp / 'kernel'])
                payload = output.read_bytes()
                payloads[index] = payload
                check('fit_hashes_present_' + str(index), bool(image['hashes']) and all(value for _, value in image['hashes']))
                for number, (algorithm, expected) in enumerate(image['hashes']):
                    actual = format(zlib.crc32(payload) & 0xffffffff, '08x') if algorithm == 'crc32' else hashlib.new(algorithm, payload).hexdigest()
                    check('fit_hash_' + str(index) + '_' + str(number), actual == expected.lower())
            if args.expected_dtb_sha1:
                check('dtb_pin_format', bool(re.fullmatch('[0-9a-f]{40}', args.expected_dtb_sha1)))
                check('dtb_matches_reference', hashlib.sha1(payloads[dtb_image['index']]).hexdigest() == args.expected_dtb_sha1)
            listing = run([args.unsquashfs, '-ll', temp / 'root']).decode('utf-8', 'replace')
            check('immutable_marker_absent', 'squashfs-root/etc/config/rd15_defaults' not in listing)
            check('qcn_board2_absent', 'squashfs-root/lib/firmware/ath12k/QCN6432/hw1.0/board-2.bin' not in listing)
            entries = parse_fs_listing(listing)
            sha1 = resolve_fs_entry(entries, 'usr/bin/sha1sum') or resolve_fs_entry(entries, 'bin/sha1sum')
            check('sha1sum_present', root_owned_not_writable(sha1, '-') and sha1['mode'][3] in ['x', 's'])
            check('admin_key_permissions', root_owned_not_writable(resolve_fs_entry(entries, 'etc/dropbear/authorized_keys'), '-'))
            check('admin_key_parent_permissions', all(root_owned_not_writable(entries.get(path), 'd') for path in ['', 'etc', 'etc/dropbear']))
            key = run([args.unsquashfs, '-cat', temp / 'root', 'etc/dropbear/authorized_keys'])
            check('public_admin_key_present', bool(key.strip()) and b'PRIVATE KEY' not in key)
            for name, source in SOURCES.items():
                content = run([args.unsquashfs, '-cat', temp / 'root', name])
                check('source_matches_' + Path(name).name, hashlib.sha256(content).digest() == hashlib.sha256(source.read_bytes()).digest())
            platform = run([args.unsquashfs, '-cat', temp / 'root', 'lib/upgrade/platform.sh'])
            check('platform_source_matches', hashlib.sha256(platform).digest() == hashlib.sha256(args.platform_source.read_bytes()).digest())
            if args.overlay:
                check('overlay_public_key_matches', key == (args.overlay / 'etc/dropbear/authorized_keys').read_bytes())
                for name in BLOBS:
                    content = run([args.unsquashfs, '-cat', temp / 'root', name])
                    check('overlay_matches_' + name.replace('/', '_'), hashlib.sha256(content).digest() == hashlib.sha256((args.overlay / name).read_bytes()).digest())
        result['passed'] = True
    except Exception as exc:
        result['error'] = str(exc) if isinstance(exc, CheckFailure) else type(exc).__name__
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--image', required=True, type=Path)
    parser.add_argument('--fwtool', default='fwtool')
    parser.add_argument('--dumpimage', default='dumpimage')
    parser.add_argument('--unsquashfs', default='unsquashfs')
    parser.add_argument('--platform-source', required=True, type=Path, help='Trusted patched SDK platform.sh for exact parity')
    parser.add_argument('--overlay', type=Path, help='Private SDK files/ overlay; compares fixed firmware paths and public admin key locally')
    parser.add_argument('--expected-dtb-sha1', help='Optional DTB pin for the tested reference')
    result = inspect(parser.parse_args())
    print(json.dumps(result, indent=2))
    return 0 if result['passed'] else 1


if __name__ == '__main__':
    sys.exit(main())
