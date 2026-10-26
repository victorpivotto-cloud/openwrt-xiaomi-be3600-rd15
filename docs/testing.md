# Reproduce host-side checks

These checks run locally and do not access or write a router. They need a
native C compiler, Python 3 and, for FDB source reconstruction, `patch`.

```sh
python3 scripts/check-rd15-fdb.py
python3 scripts/check-rd15-airtime.py --source /path/to/backports/net/mac80211/airtime.c
python3 scripts/check-rd15-aql.py --source /path/to/backports/net/mac80211/airtime.c
python3 scripts/check-rd15-envtools.py --source /path/to/u-boot/tools/env/fw_env.c
```

Use prepared sources after this port's patches have been applied. The
airtime, AQL and envtools runners also accept `--baseline /path/to/pre-fix.c`
to exercise the earlier implementation as a negative control. No original
device data or firmware image is needed by these C contract tests.

| Runner | Scope |
|---|---|
| FDB | Six contracts of actual functions reconstructed from the versioned driver patches, with mocked register I/O |
| Airtime | Nineteen cases of actual extracted C functions, with a synthetic rate table and controlled status adapters |
| AQL | Five cases of the actual fallback function, including unknown rate and missing channel context |
| envtools | Seven cases of the actual block-write function, with controlled NAND/NOR adapters, geometry rejection, sparse pages and failure/readback paths |

The synthetic NAND adapter models a partial large-write failure to distinguish
the two code paths. It does not establish the physical cause of a real NAND
failure. The rate adapters do not emulate a radio or measure OFDMA throughput.
The tests use UBSan/bounds where applicable and compile the extracted C rather
than a second implementation of its logic.

For an image built from this export, run the offline inspector described in
[upgrading.md](upgrading.md), followed by the normal on-device validation
without writing before installation. Inspect a prepared tree with
`scripts/check-public-tree.sh` and `git diff --check` before publishing source.
These checks do not authenticate an image, replace serial recovery, or
qualify power interruption, cold-boot endurance or every client's behavior.
