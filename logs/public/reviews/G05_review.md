# G05 Review: Audit of the Upstream Build and Run Scripts (read-only run)

| Field | Value |
|---|---|
| Gate | G05, first run (read-only audit) |
| Run | `G05_20261102T025456Z_lCG0ac` |
| Input script SHA-256 | `a0abc9fe33f6e77d56bf39a1bb62b60a9e3224b23c3f79ea0733d0a66830e7fd` |
| Raw log SHA-256 | `f4ba11326cd0cd629e55d1d85cd80558a4f396b1cff481f98936f87b65ac95bc` |
| Reviewed material | masked review log (1,879 lines) |
| Previous gate | G04 PASS; checkpoint 1 recorded |
| **Judgement** | **PASS** (audit complete; safety changes required before any build or run) |

## Criteria

| Criterion | Evidence (step) | Result |
|---|---|---|
| Inputs and earlier evidence intact | 3 hash checks OK; all 11 sealed files OK (1) | OK |
| G04 work and charter v1.3 committed in UTC | `6f2e410`, 3 files, `+00:00` (2) | OK |
| Host state recorded | kernel 7.0.0-38; 12 GiB available of 30 GiB (3) | OK |
| Full text of every Makefile and run script | 7 Makefiles, 8 scripts and tools files with line numbers (5, 6) | OK |
| Index of operations and external URLs | `rm -rf`, `kill`, `hostfwd`, `BR2_JLEVEL`, `-j`, URLs outside Makefiles (7) | OK |
| Build-time Git sources reachable | dtc over `git://` and HTTPS; kvmtool branch (8) | OK |
| Nothing modified | upstream clean; project shows only the G05 files (9) | OK |

## Findings

The findings are recorded, with file and line references and a decision for each, in
`docs/SAFETY_AUDIT.md` (A1-A15). Summary:

| Area | Findings | Decision |
|---|---|---|
| Parallelism | Buildroot `BR2_JLEVEL=0` hard-coded (A1); bare `-j` from `$(nproc)` in two Makefile recipes (A2); `opensbi.sh` uses all CPUs (A3); cargo outside job control (A4) | patch 0001; `BR2_JLEVEL=2`, `OMP_NUM_THREADS=2`, `CARGO_BUILD_JOBS=2` |
| Network and processes | SSH forward on all interfaces with a fixed root password (A5); `kill_users_qemu` and `kill_qemu` can kill other projects' processes (A7, A8, demonstrated with dummy processes); `known_hosts` lock-out (A9) | patch 0002 |
| Test runner | success without tests, no time limit, results in the current directory (A10) | gate rules for E8 |
| Source tree | QEMU source and Buildroot downloads inside the checkout; `cargo fmt`; OpenSBI patched by design (A11) | settings outside the checkout; `git status` and `git diff` after each build gate |
| Inputs | TAP tool on floating `stable` (A13); downloads (A14); demo secret `0xc0ffeec0ffeec0ffeec0ffee` and PCR 4 (A15) | recorded at the build gates; E6 and E7 defined |

Also resolved: `cargo-binutils` is not used by any Makefile (G04 F3); the second toolchain file
declares `stable` (G04 F1).

## Not yet recorded

The test scripts inside the emulated hypervisor (`hypervisor/rootfs/*.sh`,
`confidential-vms/linux_vm/hypervisor_rootfs/*.sh`) and the Buildroot configuration files were not
part of this run. They define the test format (E8) and the downloaded Linux version (E1).
Action: the second G05 run (G05b) records them before applying the patches.

## Next gate

G05b: record the remaining evidence, then apply patches 0001 and 0002 to the upstream checkout, with logging.
