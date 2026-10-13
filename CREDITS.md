# Credits

- [OpenWrt](https://openwrt.org/) and its upstream contributors provide the build system, kernel integration, packages and runtime.
- [fivefold3/openwrt-gl-be3600](https://github.com/fivefold3/openwrt-gl-be3600) is the pinned Qualcomm IPQ5332/GL-BE3600 base on which this experimental RD15 port is built.
- [perceival/openwrt-flint3](https://github.com/perceival/openwrt-flint3) was consulted as a technical reference for another IPQ5332 device during the RD15 investigation. It is not the pinned build base for this port.
- David Yang authored the upstream Linux YT921x DSA driver and tagger backported here. The patch retains the original licensing notices.
- Xiaomi, Qualcomm and Motorcomm supplied hardware and firmware components. Their proprietary binary files are **not** distributed in this repository.
- The RD15 port, tests and documentation were developed on one device by the RD15 maintainer with assistance from Codex and Claude. Upstream authorship remains with the original contributors.

The project is independent and not endorsed by these vendors or by OpenWrt.
