# G05b Review: Apply the Safety Patches

| Field | Value |
|---|---|
| Gate | G05b (second G05 run: remaining evidence and safety patches) |
| Run | `G05b_20261102T035410Z_z0g7ji` |
| Input script SHA-256 | `d89ee9f91ec60153fc13815269fabbae062d6ae97c39fa0937ee4857cb8d1fee` |
| Raw log SHA-256 | `a32caae7b9a9381789f7494800605afd784d1bd346ce8cc5ade999fb0c29f139` |
| Reviewed material | masked review log (631 lines) |
| Previous gate | G05 read-only audit PASS |
| **Judgement** | **PASS** |

## Criteria

| Criterion | Evidence (step) | Result |
|---|---|---|
| Inputs and earlier evidence intact | 6 hash checks OK; all 13 sealed files OK (1) | OK |
| G05 read-only work committed in UTC | `22bbf68`, 2 files, `+00:00` (2) | OK |
| Test scripts and Buildroot configurations recorded | 6 scripts, 2 configurations (3) | OK |
| Patches installed unchanged | SHA-256 equal to the delivered files (4) | OK |
| Sources are the audited commit | `HEAD = 1ebdebf`; 4 of 5 object IDs equal to the reconstructed files, the 5th explained in F1 (5) | OK |
| Both patches applied and confirmed | apply, then reverse-check OK for both (6) | OK |
| Patched state as expected | exactly 5 modified files, 16 insertions, 12 deletions; `BR2_JLEVEL=$(BR2_JLEVEL)`, `-j$(shell nproc)`; `OMP_NUM_THREADS=2 nproc` = 2 (7) | OK |

## Findings and actions

**F1. One reconstructed file differed only in its final newline and mode.**
`tools/ace_run_hypervisor.sh` at the pinned commit has no newline at the end of the file and mode 100755.
Its object ID `33b9a71d` equals the reconstructed content without the final newline, so the content was
exact. The patch used 2 lines of context, kept away from the end of the file for this reason, and applied
cleanly; the diff shows no mode change. `git apply` printed "has type 100755, expected 100644" because the
patch's metadata line recorded 100644.
Action: G06 replaces `patches/0002-run-scripts-host-safety.patch` with revision 2, whose metadata records
`33b9a71` and 100755. Its changes are identical to revision 1 (checked line by line), and G06 confirms with
`git apply --reverse --check` that revision 2 matches what is applied, before committing it.

**F2. The test format for E8 is defined.** `hypervisor/rootfs/selftest.sh` runs exactly two tests,
`test_attestation` and `test_smp`, and prints `<name>: success` or `<name>: failed` for each.
E8 is PASS only if both lines are present and both say `success`. A missing line counts as a failure,
unlike `tools/ace_test.sh`, which only counts `: failed` (SAFETY_AUDIT A10).

**F3. The attestation test defines E7.** `hypervisor/rootfs/test_attestation.sh` starts the confidential VM
with 1 vCPU and 256 MiB, loads `ace.ko` in it, and passes only if the VM's kernel log contains
`Secret=0xc0ffeec0ffeec0ffeec0ffee` exactly once. `test_smp.sh` starts it with 2 vCPUs and reads a marker
file from the confidential VM's file system.

**F4. The tests have short internal time limits.** Inside the emulated hypervisor, each test waits 5 s and
then at most 30 attempts of 1 s for the confidential VM's SSH (`hypervisor/rootfs/common.sh:14-22`).
Under nested emulation this may be too short on some hosts.
Action: a failed test is first checked for a timeout (in the test log) before it is attributed to ACE.

**F5. Linux 6.3-rc4 for both kernels.** Both Buildroot configurations set
`BR2_LINUX_KERNEL_CUSTOM_VERSION_VALUE="6.3-rc4"` and apply the CoVE and ACE patches from the repository.
Buildroot has no hash for a custom kernel version, so the download is not verified.
Action: G09 records the SHA-256 of the kernel tarball in `BR2_DL_DIR`.

**F6. The hypervisor contains a nested QEMU that must be patched.** The hypervisor configuration builds
Buildroot's QEMU package (`BR2_PACKAGE_QEMU`, riscv64 system emulation) for running the confidential VM.
`hypervisor/patches/qemu/8.1.1/cove.patch` is applied through `BR2_GLOBAL_PATCH_DIR` only if Buildroot's
QEMU version is exactly 8.1.1.
Action: G09 confirms in the build log that the patch was applied.

**F7. Toolchain declared as GCC 12 / headers 5.10.** Both configurations declare an external toolchain with
`BR2_TOOLCHAIN_EXTERNAL_GCC_12` and `BR2_TOOLCHAIN_EXTERNAL_HEADERS_5_10`; Buildroot checks this against
the real toolchain. Action: G06 records the toolchain's GCC version.

**F8. Guest credentials.** Both images use `root` / `passwd`. The host-side exposure is closed by patch 0002;
the port forward for the confidential VM (`run_linux_vm_qemu.sh:74`) is internal to the emulated hypervisor.

## Next gate

G06: `make devtools` with the build settings from `docs/SAFETY_AUDIT.md`; record the toolchain's SHA-256 and GCC version.
