#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Guard against accidentally committing local firmware, keys or logs.
# This is a checklist aid, not a substitute for reviewing every diff.
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
python3 - <<'PY'
import pathlib, re, subprocess, sys

root = pathlib.Path.cwd()
if (root / '.git').is_dir():
    paths = [pathlib.Path(x) for x in subprocess.check_output(
        ['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z']).decode().split('\0') if x]
else:
    paths = [p.relative_to(root) for p in root.rglob('*') if p.is_file() and '.git' not in p.parts]

bad_ext = {'.bin', '.img', '.itb', '.ubi', '.ubifs', '.squashfs', '.dtb',
           '.ko', '.elf', '.cpio', '.pem', '.key', '.log', '.pcap', '.cap'}
bad_names = {'authorized_keys', 'id_ed25519', 'id_rsa', 'bdata', 'art'}
reviewed_images = {
    pathlib.Path('docs/images/rd15-uart-original.jpg'),
    pathlib.Path('docs/images/rd15-uart-pinout.png'),
    pathlib.Path('docs/images/luci-overview.png'),
}
patterns = {
    'local home path': re.compile(r'/home/jvpr/'),
    'private downloads path': re.compile(r'(?:~/Downloads/|/Downloads/be3600)', re.I),
    'private key': re.compile(r'-----BEGIN (?:OPENSSH|RSA|EC|DSA) PRIVATE KEY-----'),
    'GitHub token': re.compile(r'gh[opurs]_[A-Za-z0-9]{20,}'),
    'Wi-Fi password assignment': re.compile(r'(?im)^\s*(?:option\s+key|wpa_passphrase|psk|password)\s*[=: ]\s*["\x27]?[A-Za-z0-9!@#$%^&*_-]{8,}'),
    'device MAC address': re.compile(r'\b(?:[0-9a-f]{2}:){5}[0-9a-f]{2}\b', re.I),
}
errors = []
for rel in paths:
    path = root / rel
    if not path.is_file():
        continue
    if rel.suffix.lower() in bad_ext or rel.name.lower() in bad_names:
        errors.append(f'{rel}: blocked filename')
        continue
    data = path.read_bytes()
    if rel in reviewed_images:
        magic = b'\x89PNG\r\n\x1a\n' if rel.suffix == '.png' else b'\xff\xd8\xff'
        if not data.startswith(magic) or len(data) > 3 * 1024 * 1024:
            errors.append(f'{rel}: invalid or oversized reviewed image')
        continue
    if b'\0' in data or len(data) > 1024 * 1024:
        errors.append(f'{rel}: binary or over 1 MiB')
        continue
    try:
        content = data.decode('utf-8')
    except UnicodeDecodeError:
        errors.append(f'{rel}: not UTF-8 text')
        continue
    for label, pat in patterns.items():
        if rel == pathlib.Path('scripts/check-public-tree.sh'):
            continue  # The scanner necessarily contains its own detection strings.
        if pat.search(content):
            errors.append(f'{rel}: possible {label}')

if errors:
    print('Public-tree audit failed:', file=sys.stderr)
    print('\n'.join(errors), file=sys.stderr)
    sys.exit(1)
print(f'Public-tree audit passed: {len(paths)} text files checked')
PY
