# Contributing

Contributions should target the pinned base commit and make a single technical change at a time. Explain the hardware revision, kernel/firmware combination, reproduction steps, UART or kernel evidence, and before/after behavior. Include a rollback method for changes that affect boot, UBI, Ethernet or Wi-Fi memory.

Before opening a pull request:

1. Run `scripts/check-public-tree.sh` and `git diff --check`.
2. Confirm your patch applies to a clean tree prepared with `scripts/prepare-tree.sh`.
3. Test on your own RD15 with a verified serial recovery path. Clearly mark code that has only been compiled or reviewed and not booted.
4. Remove keys, passwords, MAC addresses, serial numbers, public IPs, private LAN configuration, device dumps and proprietary firmware. Do not attach built images that contain vendor Wi-Fi files.
5. Keep upstream copyright and SPDX headers on backported code.

Issues and pull requests are welcome, but the port is experimental and there is no guaranteed support or recovery service.
