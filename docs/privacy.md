# Privacy of published test records

Household deployment details are anonymized. Management addresses use the
documentation-only subnet `192.0.2.0/24`; these are examples, not addresses
to apply unchanged to a working household LAN. Actual SSIDs, device BSSIDs,
client addresses, test-server operators and city names are omitted or replaced
with descriptive labels. Measurements and hardware findings are preserved.

Maintainer commit metadata uses a project identity and an address in the
reserved `example.invalid` domain. Upstream authorship and licensing notices
remain intact. Repository ownership and public community handles remain visible.

Published branch history was rewritten for this cleanup. Existing clones,
old commit links, third-party copies and service caches may retain older
content; a rewritten branch is not a guarantee of erasure from every copy.
Fresh clones are recommended rather than merging old history back in.

Private recovery bundles, credentials, firmware blobs, captures, calibration
and original device logs are not distributed in this repository.

The public defaults also omit the owner's chosen timezone and runtime AP
profile. Manufacturer management defaults needed by the code are retained;
documentation-only deployment addresses are examples. Built images and admin
keys remain local inputs, so this source export is not a promise of bitwise
identity with an owner's customized image.
