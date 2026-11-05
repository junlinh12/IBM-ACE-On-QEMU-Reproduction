# G00 Review: Host Baseline

| Field | Value |
|---|---|
| Gate | G00 Host Baseline |
| Run | `G00_20261030T122505Z_7St35c` |
| Input script SHA-256 | `d5c9647bf76ed3562d3225cc0cb29110d51494fe28e9af3f3d4257da89e6791b` |
| Raw log SHA-256 | `0a77937499d4e40a5417aec1f0e9a1e11b41002bad1e806545a37f83fc903e6a` |
| Reviewed material | masked review log (home path and user name masked) |
| **Judgement** | **PASS** |

## Criteria

| Criterion | Evidence (step) | Result |
|---|---|---|
| Ubuntu 24.04, x86_64 | 24.04.5 LTS, kernel 7.0.0-38-generic, x86_64 (1) | OK |
| CPU >= 4 cores | 20 cores, Intel Core Ultra 7 265K (2) | OK |
| RAM >= 4 GB | 30.7 GiB total; 14.8 GiB available at audit time; 8 GiB swap (2) | OK |
| Disk >= 50 GB (100 GB recommended) | 479.5 GiB free; 57.3 M free inodes (3) | OK |
| Host developer tools | git, make, gcc, g++, clang 18.1.3, python3, ninja, curl, wget all present (4) | OK |
| apt packages | 45 of 46 present; `llvm-dev` missing (7) | Action in G02/G03 |
| Upstream reachable | `git ls-remote` returned HEAD `1ebdebf4cacc04fcb83191053b4e979cbcdcb2d6` (9) | OK |
| Audit completeness | 36 commands run; 1 failure, explained below | OK |

The single failed command (`dpkg-query`, exit 1) is caused only by the missing `llvm-dev`.

## Findings and actions

**F1. `llvm-dev` is missing.**
It was added to the check list from an external audit that cited the upstream CI; this has not been confirmed.
Action: G02 reads the CI workflow at the pinned commit; G03 installs `llvm-dev` only if the CI requires it.

**F2. A distribution QEMU exists at `/usr/bin/qemu-system-riscv64`.**
ACE builds its own QEMU 8.2.1 (`make emulator`). A plain `qemu-system-riscv64` on `PATH` would resolve to the distribution copy.
Action: every later gate calls the ACE QEMU by its absolute path under `build/` and records `--version`.

**F3. Rust is shared with other projects.**
Default toolchain: stable 1.98.1. An older nightly is also installed, used by another project on this host.
Action: never run `rustup default nightly` (as the upstream README suggests). ACE's pinned nightly is selected
through its `rust-toolchain.toml` (directory override) and installed in G04, without changing the default.

**F4. The host is shared; about half the memory is in use.**
MemAvailable was 14.8 GiB of 30.7 GiB.
Action: build parallelism is fixed at `-j2` (project owner's decision), and memory is recorded before
each build gate. Builds will take longer than the upstream estimate (about 30 minutes with 4 jobs).

**F5. Listening TCP ports: <port>, <port>, <port>, <port>, <port>.**
Action: in G05, choose an SSH forward port for the emulated hypervisor that avoids these, and bind it to `127.0.0.1`.

**F6. Upstream HEAD matches the external audit's pin candidate.**
`1ebdebf4cacc04fcb83191053b4e979cbcdcb2d6` was reported by the external audit and is now confirmed by this run.
Action: G02 pins this commit (or records why a different one is chosen) together with all submodule commits.

**F7. Host `/dev/kvm` exists but is not used.**
The RISC-V platform runs under QEMU emulation (TCG); KVM is used inside the emulated RISC-V Linux.

## Decisions after review (project owner)

- Build parallelism: `-j2` for every build gate (G06-G12).
- Log folder: renamed from `Project Logs/` to `logs/`. Done in G01; the G00 evidence is moved
  unchanged and its SHA-256 seal is re-checked after the move.

## Next gate

G01: project skeleton, charter, Git ignore rules, local Git identity. No clone, build, or push.
