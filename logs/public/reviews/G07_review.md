# G07 Review: Build the ACE Tools (`make tools`)

| Field | Value |
|---|---|
| Gate | G07 Tools, second run (revision 2) |
| Run | `G07_20261102T084900Z_ZTrxqN` |
| Input script SHA-256 | `e42ccfec0dd998e7407af1a9600e1cf8c719a0f50fbd04e78d0be45ff74cff95` |
| Raw log SHA-256 | `40352a8e17f22a187c3185ae4dae4daa246f60223d44147cdcbd398799bc9664` |
| Reviewed material | masked review log (430 lines) |
| Previous runs | first run `G07_20261102T041114Z_vzwQUZ` BLOCKED (`G07_run1_review.md`) |
| Previous gate | G06 PASS |
| **Judgement** | **PASS** (E2: ACE scripts installed with patch 0002; TAP tool built; E1: crates recorded) |

## Criteria

| Criterion | Evidence (step) | Result |
|---|---|---|
| Inputs and earlier evidence intact | 2 hash checks OK; all sealed files OK, including the first G07 run (1) | OK |
| No duplicate commit | G06 already committed (`1e7d46d`); nothing staged (2) | OK |
| Rust 1.98.1 added without changing the shared setup | 4 components installed; default still `stable` (5) | OK |
| Selected compiler equals the host's stable | both `rustc 1.98.1 (48a229cea 2026-09-01)`; `rustfmt 1.9.0-stable` available (6) | OK |
| `make -j2 tools` succeeded | 9 s (08:49:06-08:49:15 UTC); `Finished release profile` (7) | OK |
| Tools installed | 9 files in `$ACE_DIR/tools`; `cove-tap-tool` 1,338,664 bytes, SHA-256 `f2a6d7dc4f8671336f4bc53cae10ea824afcc6f6c91ff55773477f8f3efcf1eb`; `--help` lists `attach`, `generate`, `measure` (8) | OK |
| Installed scripts contain patch 0002 | `hostfwd=tcp:127.0.0.1:` and `UserKnownHostsFile=/dev/null` found once each (8) | OK |
| Crates recorded | 57 crate files in `build/cargo-home` (32 MB), equal to the 57 `Downloaded` lines (7, 9) | OK |
| Upstream tree unchanged by the build | still exactly the 5 patched files; `cargo fmt` changed nothing (10) | OK |
| Shared Rust setup unchanged | default `stable`; `stable` components `cargo`, `rust-std`, `rustc` (no `rustfmt`) (10) | OK |

## Findings and actions

**F1. SAFETY_AUDIT A13 is resolved.** The TAP tool, declared for the floating `stable`, was built with the pinned
toolchain `1.98.1`, verified identical to the host's `stable` at build time. `docs/SAFETY_AUDIT.md` (revision 2)
and `docs/SOURCE_PROVENANCE.md` record this.

**F2. `cargo fmt` ran and changed nothing.** The TAP tool's `build` target depends on `fmt`; the upstream sources
are already formatted for `rustfmt 1.9.0`.

**F3. Cargo warned that it could not use make's job server.** The message `failed to connect to jobserver ...
Bad file descriptor` appears twice. Make passes its job server only to recursive `$(MAKE)` lines, and the cargo
line is not one (SAFETY_AUDIT A4), so cargo fell back to its own limit, `CARGO_BUILD_JOBS=2`. Harmless; no action.

**F4. Available memory is falling.** 12 GiB at G06, 7.6 GiB before and 7.1 GiB after this gate (other workloads
on the host; the build itself is small).
Action: from G08, every build gate checks that at least 4 GiB is available before building and stops otherwise.

**F5. `ls -l` printed local times** (17:49 for an 08:49 UTC build), which reveals the time zone (same issue as G03 F3).
Action: from G08, the logging harness sets `TZ=UTC0`, so every time printed by the gate scripts is in UTC.

**F6. Build-time downloads are noisy.** The QEMU download in G08 runs `wget` without `-q`, which prints thousands of
progress lines. Action: `scripts/build_env.sh` (revision 2) sets `WGETRC` to `scripts/wgetrc` (`verbose = off`),
so `wget` prints one line per download. This changes log output only.

## Next gate

G08: `make emulator` (QEMU 8.2.1 for the emulated RISC-V platform); record the source tarball's SHA-256, the QEMU
version, the features used by the run scripts (`virt` machine, `rv64` CPU, user networking), and the binary's SHA-256.
