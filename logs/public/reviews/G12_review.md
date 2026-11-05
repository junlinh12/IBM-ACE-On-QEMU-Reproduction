# G12 Review: Integrated Rebuild and End-to-End Artifact Audit

| Field | Value |
|---|---|
| Gate | G12 Rebuild All |
| Run | `G12_20261104T091034Z_XoudcY` |
| Input script SHA-256 | `0e274dc9e9feaed7400bddd8b9ce9346ecdacb37ba8433f7a36219d3d270312d` |
| Raw log SHA-256 | `7f3be7a44f2737747a49379308c6cc5264e68e9904c190c136ce21f1ddf41b23` |
| Reviewed material | masked review log (879 lines) |
| Previous gate | G11 PASS |
| **Judgement** | **PASS** (E2 complete: every component rebuilt and traced; the gap of G11 is closed inside the image that G13 boots) |

## Criteria

| Criterion | Evidence (step) | Result |
|---|---|---|
| Inputs and evidence intact | hash checks OK; all sealed files OK (1) | OK |
| G11 work committed in UTC | `e1eb63a`, 3 files (G11, SOURCE_PROVENANCE) (2) | OK |
| Memory and disk | 11,830,688 kB available; 462 GB free (3) | OK |
| State before the rebuild | `fw_payload.elf` `6a41b581...`, `libace.a` `2f3e87b7...`, hypervisor `rootfs.ext2` `a1e289a0...`, VM disk `d392fdab...`, overlay copy `030d9dcc...` (all = G10/G11) (4) | OK |
| Rust 1.98.1 equal to `stable` | both `rustc 1.98.1 (48a229cea 2026-09-01)` (5) | OK |
| Rebuild in the order of `all` | `emulator`, `tools` (1.98.1), `firmware` (nightly), `confidential_vms` (1.98.1); 21 s (09:10:35-09:10:56 UTC); no error (6) | OK |
| Firmware reproducible | `fw_payload.elf` `6a41b58184c3...c286` and `libace.a` `2f3e87b742...bd76`, identical to G10; payload = G09 `Image` at `0x200000` (7) | OK, see F1 |
| Hypervisor carries the current VM kernel and TAPs | `Image` `d10c9b01...` and both TAPs extracted with `debugfs` equal the current files (`cmp` silent) (8) | OK |
| Hypervisor carries the final VM disk | extracted `rootfs.ext2` = overlay copy = `d392fdab...`, the disk that G11 rebuilt with `ace.ko` (8) | OK |
| **Gap of G11 closed** | the carried VM disk contains `/root/ace_module/ace.ko`, 6,376 bytes, SHA-256 `5abaf238...4917`, identical to the built module (9) | OK |
| Measurements unchanged | carried VM kernel: PCR 4 `0x4e73d007...da33` (QEMU) and `0x968eb5f1...ad18` (kvmtool), = G11 (9) | OK |
| Test files in the hypervisor | `/root`: `common.sh`, `selftest.sh`, `test_attestation.sh`, `test_smp.sh`, `run_linux_vm_qemu.sh`, `run_linux_vm_kvmtool.sh`, `lkvm-static` (1,345,984 bytes), `linux_vm/` (8) | OK |
| Final images | hypervisor `rootfs.ext2` `cc07c2dc1d60a3c38bbacfa2a7d7e5f64cccf41d55e625027875b0242a2ceeed`; firmware `fw_payload.elf` `6a41b58184c3f25db92b036635abf9738df2a4b375e63c58100e313473b8c286` (10) | OK |
| Upstream tree and project | the 5 patched files and the patched OpenSBI submodule only; only the G12 files untracked (10) | OK |

## Findings and actions

**F1. The firmware build is reproducible on this host.** Rebuilding the security monitor and OpenSBI two days after G10 produced
byte-identical `libace.a` and `fw_payload.elf`.

**F2. TAP files are not reproducible, their measurements are.** The rebuild regenerated both TAPs with the same PCR 4 values,
but their SHA-256 changed (`cove_tap_qemu` `14635887...` -> `1c28e8990d987de81490dba30885f84a59a60217aee60adc769454dc6cc8ed9d`,
`cove_tap_kvmtool` `bf94cab5...` -> `4e8262b0896a649f99b213db2bfca0f748f59aabee025b310d7316040883453e`). `cove-tap-tool generate`
evidently includes fresh randomness (for example key encapsulation). TAPs must be compared through their measurements, not their
file hashes. The TAPs carried by the hypervisor are the ones of this rebuild.

**F3. The VM disk is regenerated after the copy, as expected.** The newest VM `rootfs.ext2` is `110d555a...`, different from the
carried copy `d392fdab...`, because the `rootfs` step runs after the copy (G11 F2). Both contain `ace.ko`; the hypervisor carries
`d392fdab...`. This is why the check is made on the carried content and not on the newest file.

**F4. The upstream "rebuild all" needs a second pass because of an ordering issue in `confidential-vms/linux_vm/Makefile`.** A
reproduction that runs `make confidential_vms` only once boots a VM without `ace.ko`. This is a property of the pinned upstream
commit, recorded for the report; no patch is made, because the upstream CI's own second pass is the intended remedy.

**F5. Swap use on the host is 5.3 GiB** (other work); available memory 11 GiB. The boot gates need more memory than the builds
(the emulated platform has 4 GiB). Action: G13 requires at least 6 GiB available before booting.

## Next

G13: boot the emulated RISC-V platform (OpenSBI, ACE security monitor, Linux hypervisor) with the upstream run script, record the
boot log (E3), and check KVM inside the emulated Linux (E4).
