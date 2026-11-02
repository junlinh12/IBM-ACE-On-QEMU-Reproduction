# Safety Audit of the Upstream Build and Run Scripts

Audited in G05 (read-only run `G05_20261102T025456Z_lCG0ac`) against IBM/ACE-RISCV
`1ebdebf4cacc04fcb83191053b4e979cbcdcb2d6`. Line numbers refer to that commit.

The host is shared with other experiments, so the audit asks, for every Makefile target and run
script used by the reproduction: what does it delete, kill, expose, modify, download, and how many
jobs does it start? Each finding ends with a decision: a patch (see `patches/`), a build setting,
or a rule for the later gates.

## Findings

### Parallelism (charter 4.7: 2 jobs)

**A1. Buildroot runs with CPUs + 1 jobs and cannot be overridden.**
`hypervisor/Makefile:53,54,67` and `confidential-vms/linux_vm/Makefile:60,61,70` pass `BR2_JLEVEL=0`,
which Buildroot turns into "number of CPUs + 1" (21 on the reference host).
Decision: patch 0001 makes `BR2_JLEVEL` a variable with the upstream default 0; the build sets `BR2_JLEVEL=2`.

**A2. Two recipes run make with an unlimited number of jobs.**
`hypervisor/Makefile:89` (kvmtool) and `security-monitor/Makefile:60` (OpenSBI) write `-j$(nproc)`.
In a Makefile, `$(nproc)` is an undefined make variable, so the option becomes a bare `-j`.
Decision: patch 0001 changes it to `-j$(shell nproc)` (the intended meaning); the build sets
`OMP_NUM_THREADS=2`, and GNU `nproc` then reports 2.

**A3. A shell script uses all CPUs.** `security-monitor/rust-crates/opensbi.sh:35,36` run `make -j$(nproc)`.
Decision: no patch needed; `OMP_NUM_THREADS=2` limits `nproc` to 2.

**A4. Cargo is outside make's job control.** The cargo builds (`security-monitor/Makefile:34`,
`tools/cove_tap_tool/Makefile:27`) run in recipes without `$(MAKE)`, so cargo uses all CPUs.
Decision: the build sets `CARGO_BUILD_JOBS=2`.

### Network exposure and processes (run scripts)

**A5. The guest's SSH port is forwarded on all host interfaces.**
`tools/ace_run_hypervisor.sh:66` uses `hostfwd=tcp::${HOST_PORT}-:22`; the guest accepts `root` with
the fixed password `passwd` (`tools/common.sh:7-8`). While the emulated hypervisor runs, anyone on the
network could log in to it.
Decision: patch 0002 forwards on `127.0.0.1` only.

**A6. The random SSH port can collide with a port in use.** `tools/ace_run_hypervisor.sh:15` picks a
port in 3000-5999; the reference host listens on <port> (G00). A collision makes QEMU fail to start;
it does not expose anything. Decision: accepted; the run gates check the listening ports first.

**A7. `kill_users_qemu` kills every QEMU of the user.** `tools/common.sh:22-29` (used by `ace stop`,
`tools/ace_stop.sh:14`) sends `kill -9` to every process of the user whose `ps aux` line contains
`qemu`: QEMU instances of other projects, and even an editor with "qemu" in a file name.
Decision: patch 0002 selects only processes running `${ACE_DIR}/qemu/bin/qemu-system-riscv64`;
in addition, the gates never call `ace stop`.

**A8. `kill_qemu PORT` can kill unrelated processes.** `tools/common.sh:31-39` (used at the end of
`tools/ace_test.sh:28` and `tools/ace_start.sh:28`) selects processes whose `ps aux` line contains
`qemu` and the port digits anywhere (PIDs, memory columns, file names). A test with dummy processes
showed that `kill_qemu 4321` selects another project's QEMU and an editor.
Decision: patch 0002 selects only the process with the exact rule `hostfwd=tcp:127.0.0.1:PORT-:22`.

**A9. ssh writes to `~/.ssh/known_hosts` and can then lock itself out.** `tools/common.sh:11` uses
`StrictHostKeyChecking=no`, which still stores the guest key in the user's `known_hosts`. When a
later boot presents a new key on the same port, ssh disables password login and `wait_for_ssh`
(`tools/common.sh:15-20`) loops forever.
Decision: patch 0002 adds `UserKnownHostsFile=/dev/null` and `LogLevel=ERROR`.

**A10. The test runner can report success without tests, and can hang.**
`tools/ace_test.sh:30-36` exits 0 when no line contains `: failed`, including when the result file is
empty; `wait_for_ssh` has no time limit; the result files `.run_tests.log` and `ace_test_results` are
written to the current directory.
Decision: no patch. The test gate runs `ace test` from `ACE_DIR` under `timeout`, copies the result
files into `logs/`, and judges E8 from the result lines (number of tests, passed, failed), not from
the exit code.

### Changes to the source tree

**A11. Some targets write into the upstream checkout.**

| Write | Where | Decision |
|---|---|---|
| QEMU source download and unpack | `Makefile:10,79-84` (default `upstream/ACE-RISCV/qemu/`) | `QEMU_SOURCE_DIR` set outside the checkout |
| Buildroot package downloads | Buildroot default `dl/` inside the `hypervisor/buildroot` submodule | `BR2_DL_DIR` set outside the checkout |
| Toolchain tarball, deleted after unpacking | `Makefile:45-48` (current directory) | accepted (temporary); G06 records the tarball's SHA-256 from a separate download |
| `cargo fmt` rewrites Rust sources | `security-monitor/Makefile:30,79-80`, `tools/cove_tap_tool/Makefile:23,41-42` | accepted; every build gate records `git status` and `git diff` of the checkout |
| OpenSBI patched and unpatched in the submodule | `security-monitor/Makefile:54-57,65-68`, patch `security-monitor/platform/opensbi_v1.4.patch` | by design; recorded after each build gate |
| Crates downloaded to the shared `~/.cargo` | cargo default | `CARGO_HOME` set inside `build/` |

**A12. Every deletion stays inside the build directories.** All `rm -rf` targets derive from
`ACE_DIR`, `QEMU_SOURCE_DIR`, or work directories below them (`Makefile:43,79,97,100,104`;
`hypervisor/Makefile:39,77,85,95`; `confidential-vms/linux_vm/Makefile:47,80,98`;
`security-monitor/Makefile:36,42,50`; `security-monitor/rust-crates/opensbi.sh:30`).
Rule: `ACE_DIR` always points into `build/`; the targets `clean`, `verify`, and
`generate_refinedrust_translation` are never run.

### Inputs

**A13. The TAP tool floats with the host's stable Rust.** `tools/cove_tap_tool/rust-toolchain.toml`
declares `channel = "stable"`, which is the host's shared stable toolchain (1.98.1 at G04).
Decision: G07 records the exact version; the stable toolchain is not updated during the project.

**A14. Build-time downloads confirmed.**

| Download | Declared in | State at G05 |
|---|---|---|
| RISC-V GNU toolchain `riscv64-glibc-ubuntu-22.04-gcc-nightly-2023.09.27-nightly` | `Makefile:17,45` | SHA-256 recorded in G06 |
| QEMU 8.2.1 | `Makefile:13,82` | SHA-256 recorded in G08 |
| dtc, default branch over `git://` | `hypervisor/Makefile:78` | reachable; HEAD `c22868416b8db8354ce5db29d3494dda688a2ae3` |
| kvmtool, branch `cove-integration-03072023` | `hypervisor/Makefile:86` | branch at `177a4df3a0ffed726d709e8bdeeec4bd4cc8239e` |
| Buildroot package sources | Buildroot configuration | configuration recorded in G05b |
| Rust crates | `Cargo.lock` files (versions and checksums pinned) | downloaded in G07 and G10 |

**A15. Demo secret and measurement.** `confidential-vms/linux_vm/Makefile:82-83,88-89` measure the
confidential VM kernel with `cove-tap-tool measure` (base address `0x80000000` for QEMU,
`0x80200000` for kvmtool) and generate the TAP with PCR 4 and secret `0xc0ffeec0ffeec0ffeec0ffee`.
This defines what E6 (measurement in the TAP) and E7 (the secret released to the VM) must show.

## Build settings used from G06 on

Every build gate runs `make` in `upstream/ACE-RISCV` with these settings:

| Setting | Value | Finding |
|---|---|---|
| `ACE_DIR` | `$PROJECT_ROOT/build/ace/` | A12 |
| `QEMU_SOURCE_DIR` | `$PROJECT_ROOT/build/qemu-source/` | A11 |
| `BR2_DL_DIR` | `$PROJECT_ROOT/build/dl` | A11 |
| `CARGO_HOME` | `$PROJECT_ROOT/build/cargo-home` | A11 |
| `BR2_JLEVEL` | `2` | A1 (needs patch 0001) |
| `OMP_NUM_THREADS` | `2` | A2, A3 |
| `CARGO_BUILD_JOBS` | `2` | A4 |
| `make -j2` | top-level job limit | charter 4.7 |

After patches 0001 and 0002, the upstream checkout is expected to show exactly these modified files,
plus any changes made by the build itself (A11), which each gate records:
`confidential-vms/linux_vm/Makefile`, `hypervisor/Makefile`, `security-monitor/Makefile`,
`tools/ace_run_hypervisor.sh`, `tools/common.sh`.
