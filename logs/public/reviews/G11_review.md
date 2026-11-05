# G11 Review: Build the Confidential VM and Repack the Hypervisor (`make confidential_vms`)

| Field | Value |
|---|---|
| Gate | G11 Confidential VMs |
| Run | `G11_20261102T132117Z_URiLe8` |
| Input script SHA-256 | `823ee81068c2065fafe15e4bfd34a30eb21eadc79112340f5e4e332ba0457851` |
| Raw log SHA-256 | `553d07d80e383a11f3c571618f63da5194e03a21968a3871b03715ca6a77c073` |
| Reviewed material | masked review log (9,435 lines) |
| Previous gate | G10 PASS |
| **Judgement** | **PASS** (E2: confidential VM, `ace.ko`, TAPs, dtc, kvmtool built; E1: dtc and kvmtool commits and new downloads recorded). The hypervisor does not yet carry the final VM disk, as predicted (F2); G12 closes this. |

## Criteria

| Criterion | Evidence (step) | Result |
|---|---|---|
| Inputs and evidence intact | hash checks OK; all sealed files OK (1) | OK |
| G10 work committed in UTC | `5617893`, 2 files (2) | OK |
| Memory and disk | 9,387,572 kB available; 466 GB free (3) | OK |
| State before the build | hypervisor `rootfs.ext2` `bf135f13...` (= G09); TAP tool `f2a6d7dc...` (= G07) (4) | OK |
| Rust 1.98.1 equal to `stable` | both `rustc 1.98.1 (48a229cea 2026-09-01)` (5) | OK |
| `make -j2 confidential_vms` succeeded | 10 min 29 s (13:21:18-13:31:47 UTC); no make error; 262 Buildroot step messages; TAP tool rebuild a no-op (`Finished ... in 0.04s`) (5) | OK |
| Confidential VM | `Image` 22,032,384 bytes, SHA-256 `d10c9b0100b8028ec604d0ef77379c5dbab67624a9696885120dbf3c24a37915`; `rootfs.ext2` 128 MiB, SHA-256 `d392fdaba423c77a77c07bffa2a8b0024d333c83734df23683a95e8b6ab80484`; built by Bootlin GCC 13.2.0 (6) | OK |
| Guest patches and configuration | `confidential-vms/linux_vm/patches/linux/6.3-rc4/0001-cove.patch`, `0002-ace.patch`; `CONFIG_RISCV_COVE_GUEST=y`, `CONFIG_MODULES=y` (6) | OK |
| `ace.ko` | SHA-256 `5abaf238e7be54920fc4310dec9698e67eaf4815fbf7dd3258e90ad02f5a4917` (6) | OK, see F3 |
| TAPs and measurements | `cove_tap_qemu` 1,756 bytes, SHA-256 `146358876e81d76660f230f20777a19119e00686339ce623b3bdf7cbb58505a1`, PCR 4 = `0x4e73d007ac0f79c9e476f42ead1ad1299cffc44ddd0719c690b368e22040da33` (base `0x80000000`); `cove_tap_kvmtool` 1,756 bytes, SHA-256 `bf94cab5142c2a2b83f2e2e68b68217a04a7062a3be065b1e79bc2e99ea2eab9`, PCR 4 = `0x968eb5f1ba52df2c2c33b394c4db642289d475150269af5517295d3b9bdead18` (base `0x80200000`); the re-measured values equal those passed to `generate` during the build (5, 7) | OK |
| TAP tool unchanged | `f2a6d7dc...` after the rebuild (7) | OK |
| dtc | `git://git.kernel.org/pub/scm/utils/dtc/dtc.git`, `19f15dae64059b1a1e05a540a57930086c46a8c0` (2026-11-02, "libfdt: Check node names in one pass in fdt_next_tag()"), libfdt 1.8.1 (5, 8) | OK, see F4 |
| kvmtool | `github.com/wojciechozga/kvmtool`, branch `cove-integration-03072023`, `177a4df3a0ffed726d709e8bdeeec4bd4cc8239e` (2025-04-06, "riscv: cove: Preload memory regions"); `lkvm-static` static RISC-V ELF, SHA-256 `17206a163b9117903e40d379fdad433e27a185b9ca21daca10dff1ea7b3663d4`; built with `-j2` (5, 8) | OK |
| Hypervisor repacked | overlay holds the 6 test and run scripts, `lkvm-static`, and the VM's `Image`, `rootfs.ext2`, and both TAPs; hypervisor `rootfs.ext2` changed to `a1e289a042c80092a3eaaef48c42aa5c4fd99d50e0a58e12da402faebe6a4d6c` (9) | OK |
| New downloads | `nvme-1.12.tar.gz` (`a75270e6...`), `opensbi-1.3.tar.gz` (`2c0501eb...`); all other sources reused (10) | OK |
| Upstream tree and project | unchanged apart from the patches and the patched OpenSBI submodule; Buildroot submodule clean; only the G11 files untracked (11) | OK |

## Findings and actions

**F1. `RUSTUP_TOOLCHAIN=1.98.1` was needed and sufficient.** The `tools` prerequisite rebuilt the TAP tool (with `cargo fmt`)
without error, and nothing else compiled Rust.

**F2. The predicted gap is real.** The VM's final `rootfs.ext2` (`d392fdab...`, rebuilt with `ace.ko`) differs from the copy in the
hypervisor's overlay (`030d9dcc...`), because the upstream Makefile copies the disk (`confidential-vms/linux_vm/Makefile:86`)
before it rebuilds it (`:93-94`). The hypervisor root file system built in this gate therefore carries a VM disk without `ace.ko`;
booting it would make the attestation test fail for a reason unrelated to ACE.
Action: G12 repeats the upstream "rebuild all" and checks, inside the hypervisor's `rootfs.ext2` itself, that the VM disk and the
TAPs equal the current ones.

**F3. `ace.ko` is built with a different compiler than the VM kernel.** The module build printed
`warning: the compiler differs from the one used to build the kernel`: `ace.ko` is compiled with the G06 toolchain (GCC 12.2.0,
`CC="riscv64-unknown-linux-gnu-gcc"` in `confidential-vms/linux_vm/Makefile:77`), the kernel with Bootlin's GCC 13.2.0. This is the
upstream configuration and the same in the upstream CI. Whether the module loads is shown by the attestation test (G14).

**F4. dtc moved since G05.** G05 saw dtc's default branch at `c22868416b8d`; this build used `19f15dae6405`, committed on the day
of the build. The upstream Makefile does not pin dtc, so a later reproduction may build a different libfdt. kvmtool's branch
did not move. Action: `docs/SOURCE_PROVENANCE.md` records both commits as used here.

**F5. The confidential VM's Buildroot also builds OpenSBI 1.3** (`fw_jump`, `fw_dynamic` in its images; `BR2_TARGET_OPENSBI` in its
configuration). These files are not copied into the hypervisor and are not used: the platform firmware is the one from G10.

**F6. The host is under memory pressure from other work.** Swap use rose from 2.5 GiB to 4.4 GiB during the build while available
memory stayed at 9-11 GiB. The build itself stayed within its limits (`BR2_JLEVEL=2`, `-j2`). No action.

## Next

G12: the upstream "rebuild all" (`make` = `emulator tools firmware confidential_vms`), run as these four targets in order, with
`RUSTUP_TOOLCHAIN=1.98.1` only for `tools` and `confidential_vms`; then check the final images end to end.
