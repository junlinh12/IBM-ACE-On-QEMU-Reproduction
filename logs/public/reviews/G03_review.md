# G03 Review: Install the Missing Ubuntu Package

| Field | Value |
|---|---|
| Gate | G03 Apt Packages |
| Run | `G03_20261030T132027Z_gN9Ntr` |
| Input script SHA-256 | `0760b8dd09cf499b0e86698527a09c1cafb70a2b034b0a664a69b21780ad6e64` |
| Raw log SHA-256 | `ee29b98c5d33b2a0e2f7d0069a3d37632b9cbea7aa7c40317e7ca23af1762fd9` |
| Reviewed material | sealed raw log (hashes of the raw log and input script verified against the seal) |
| Previous gate | G02 PASS |
| **Judgement** | **PASS** |

## Criteria

| Criterion | Evidence (step) | Result |
|---|---|---|
| Inputs and earlier evidence intact | 3 hash checks OK; all 7 sealed files OK (1) | OK |
| G02 work committed in UTC | `3ee5ab0`, 4 files, date `+00:00` (2) | OK |
| Only `llvm-dev` missing before install | `llvm-dev` Installed: (none); `clang`, `libclang-dev` installed (3) | OK |
| Simulation: no removal, no upgrade | `remove=0 upgrade=0`; 1 new package (4) | OK |
| Install changed only `llvm-dev` | 1 newly installed, 0 upgraded, 0 removed; apt history: `Install: llvm-dev:amd64 (1:18.0-59~exp2)` (5, 6) | OK |
| All CI packages present | 46 of 46 `install ok installed` (6) | OK |
| Project tree as expected | 2 commits; only the G03 files untracked (7) | OK |

## Findings and actions

**F1. Minimal change to the shared host.** `llvm-dev` is a 1.9 kB metapackage; its dependencies were already
installed with `clang`/`libclang-dev`. The "no longer required" packages listed by apt (an older kernel)
were not touched; this project never runs `autoremove`.

**F2. A newer kernel is installed but not running.** The apt history shows an `apt upgrade` on the same day,
before G00, that installed kernel 7.0.0-42, while G00 recorded the running kernel 7.0.0-38. A reboot is pending.
The RISC-V platform is emulated, so the host kernel does not affect the build.
Action: every build gate records `uname -r`; a reboot between gates is allowed and will be visible in the logs.

**F3. Logs contain local times.** `/var/log/apt/history.log` uses the host's local time
(22:20:36 for the 13:20:36 UTC install), which reveals the time zone.
Action: G16 checks every file proposed for `logs/public/` for local timestamps, in addition to the
commit-date normalization already planned (G02 F8).

**F4. A third-party apt repository is configured** (Google Chrome). It was refreshed by `apt-get update`
but nothing from it was installed. No action.

## Next gate

G04: install Rust `nightly-2026-03-23` with target `riscv64gc-unknown-none-elf`, as declared in the pinned
`rust-toolchain.toml`, without changing the default toolchain; record which Rust tools the upstream build uses.
