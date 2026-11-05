# G09 Review: Build the RISC-V Linux Hypervisor Image (`make hypervisor`)

| Field | Value |
|---|---|
| Gate | G09 Hypervisor, second run (revision 2) |
| Run | `G09_20261102T115757Z_b6e4Mk` |
| Input script SHA-256 | `cbdca51e5aafc00480951fb5edd54df11304a002615ff4f4dc2749484f61f6b7` |
| Raw log SHA-256 | `1e8e8e790b7d003f15940053a64c45d3bf84d373f95f437023f406d6a88a50f5` |
| Reviewed material | masked review log (25,546 lines) |
| Previous runs | first run `G09_20261102T114120Z_PLjTHu` BLOCKED (`G09_run1_review.md`) |
| Previous gate | G08 PASS |
| **Judgement** | **PASS** (E1: Linux source verified by commit, all 46 sources hashed; E2: hypervisor kernel and root file system built, CoVE patches applied). One recording command failed (F5). |

## Criteria

| Criterion | Evidence (step) | Result |
|---|---|---|
| Inputs and evidence intact; no duplicate commit | hashes OK; G08 already committed (`f949474`) (1, 2) | OK |
| Memory and disk | 9,170,624 kB available; 473 GB free (3) | OK |
| Cause of the first failure recorded | `/torvalds/t/linux-6.3-rc4.tar.gz` -> 301 -> `.../linux.git/snapshot/linux-6.3-rc4.tar.gz` -> **502 Bad Gateway** (nginx), for both curl and wget (5) | OK, see F1 |
| Linux source created from kernel.org Git | tag `v6.3-rc4` = `197b6b60ae7bc51dd0814953c562833143b292aa` (2023-03-26T14:40:20-07:00, "Linux 6.3-rc4"); `linux-6.3-rc4.tar.gz` 223,281,349 bytes, SHA-256 `3c35981844236716b0a69742bab9656e53d6f4b576cc6bc5cd05fcce126e2a10` (6) | OK |
| Three independent commits equal | kernel.org tag, GitHub tag, and the commit stored in the tarball all `197b6b60...92aa` (7) | OK |
| Tarball placed for Buildroot | same SHA-256 in `build/dl/linux/` (8) | OK |
| `make -j2 hypervisor` succeeded | 14 min 18 s (12:08:55-12:23:13 UTC); no make error; 421 Buildroot step messages (9) | OK |
| Hypervisor images | `Image` 22,030,848 bytes, SHA-256 `75a0db25e8f28f415d93b490bbaf4f1bf4b31b6c22685556bfe32adf056308d7` (RISC-V 64-bit kernel image with EFI header); `rootfs.ext2` 536,870,912 bytes (512 MiB), SHA-256 `bf135f136ab0504fe7ddbb43897113f012266578165a3cfa61f1eac0926facab` (10) | OK |
| Kernel patches applied | `hypervisor/patches/linux/6.3-rc4/0001-cove.patch`, `0002-ace.patch` (10) | OK |
| Nested QEMU patched | QEMU 8.1.1: Buildroot's 3 patches and `hypervisor/patches/qemu/8.1.1/cove.patch` (10) | OK, see F2 |
| Kernel configured for CoVE and KVM | `CONFIG_RISCV_COVE_HOST=y`, `CONFIG_KVM=y` (10) | OK |
| Nested QEMU installed | `target/usr/bin/qemu-system-riscv64`, 12,665,792 bytes (10) | OK |
| Sources recorded | 46 source files in 45 package directories, with SHA-256; 573 MB; Buildroot reported no hash error (11) | OK |
| Upstream tree, Buildroot submodule, project | 5 patched files only; submodule clean; only the G09 files untracked (12) | OK |

## Findings and actions

**F1. The first run failed because git.kernel.org returned 502.** Buildroot's URL for a release candidate redirects to cgit's
on-demand snapshot, which answered `502 Bad Gateway` to both curl and wget. It was a server error of the snapshot service,
not the bot protection suspected in the first-run review. kernel.org's Git service worked, and the tarball built from it
carries the commit that both kernel.org and GitHub assign to `v6.3-rc4`. The confidential VM (G11) reuses this file.
Action: `docs/SOURCE_PROVENANCE.md` records the method and the values.

**F2. G05b review F6 is resolved.** Buildroot 2023.11 builds QEMU 8.1.1, so the CoVE patch for the nested QEMU in
`hypervisor/patches/qemu/8.1.1/` was applied, as listed in `.applied_patches_list`.

**F3. Buildroot used Bootlin's toolchain `riscv64-lp64d--glibc--bleeding-edge-2023.08-1`.** Its tarball is in the download
directory with SHA-256 `9eda527aea5ce7da27957c3b8e4adb65430be046b713dca25432a09cb6675976` (checked by Buildroot against its
own hash file). This confirms the correction in the first-run review (G06 review F1 was wrong).

**F4. The build was short and quiet in memory.** 14 min 18 s with 2 jobs; available memory 8.7 GiB before and 8.8 GiB after.
The hypervisor build directory takes 6.3 GB, the downloads 573 MB. 2,159 lines contain "warning" (compiler and configure
warnings of the packages); none stopped the build.

**F5. One recording command failed: the Bootlin compiler version.** Step 11 looked for `host/bin/*-linux-gnu-gcc`; no file
matched, so the command became `'' --version` (exit 127). This is a fault in the gate script, not in the build.
Action: G10 finds the compiler under the Buildroot directory and records its version.

**F6. The build output contains the home path.** The Linux image, the root file system, and the Buildroot build tree embed
absolute paths of this host. They are never published (`build/` is ignored, charter 4.4); only their hashes are recorded.

## Next

Checkpoint 2 (10 gates completed), then G10: `make firmware` (OpenSBI with the ACE security monitor, with the hypervisor
`Image` as payload).
