# G04 Review: Install the Pinned Rust Toolchain

| Field | Value |
|---|---|
| Gate | G04 Rust Toolchain |
| Run | `G04_20261102T023215Z_DtsO6K` |
| Input script SHA-256 | `48e3362b5575ea72013f7a88d8fe6e5c48fb8e8590ee1d5f3b66cdb17d81c8ea` |
| Raw log SHA-256 | `a199c6decaa122f8d4dddb82f15050ccbbdac69099277299838fae49c254eeb7` |
| Reviewed material | masked review log |
| Previous gate | G03 PASS |
| **Judgement** | **PASS** |

## Criteria

| Criterion | Evidence (step) | Result |
|---|---|---|
| Inputs and earlier evidence intact | G03 review hash OK; all 9 sealed files OK (1) | OK |
| G03 work committed in UTC | `5cbf58c`, 2 files, `+00:00` (2) | OK |
| Pinned nightly installed | `nightly-2026-03-23` = `rustc 1.96.0-nightly (562dee482 2026-03-21)`, 7 components, 21 s (5) | OK |
| Target and components | `riscv64gc-unknown-none-elf`; `cargo clippy rust-docs rust-std rustc rustfmt` (6) | OK |
| Selected inside the upstream tree | active toolchain overridden by `rust-toolchain.toml` (6) | OK |
| Default toolchain unchanged | `stable` (1.98.1) before and after; outside the upstream tree stable is active (3, 6) | OK |
| Project tree as expected | 3 commits; only the G04 files untracked (7) | OK |

## Findings and actions

**F1. A second toolchain file exists: `tools/cove_tap_tool/rust-toolchain.toml`.**
The TAP tool may declare a different toolchain than the security monitor. When `make tools` (G07) runs
inside that directory, rustup would select, and possibly download, that toolchain implicitly.
Action: G05 records its content; any extra toolchain is installed explicitly by a gate, never implicitly during a build.

**F2. The G04 scan missed `$(CARGO)` calls.** The pattern was case-sensitive and matched only the lowercase
word `cargo` (for example `CARGO = cargo`), not the calls written as `$(CARGO) build` or `$(CARGO) fmt`.
Action: G05 records the full text of every Makefile with line numbers, which covers all calls.

**F3. `cargo-binutils` appears not to be needed.** No Makefile line mentions `objcopy` or `cargo objcopy`.
Action: confirmed or rejected by the full Makefile text in G05.

**F4. Rust projects in the pinned commit.** `security-monitor` (with 4 local crates) and `tools/cove_tap_tool`.
`verification/Makefile` uses `cargo-refinedrust`, which belongs to the formal verification (out of scope) and is not installed.

**F5. `clippy` is installed but only used by optional `clippy` targets.** The CI build order does not call them. No action.

## Next gate

Checkpoint 1 (5 gates completed), then G05: read-only audit of the Makefiles, run scripts, and build
configuration for side effects, external downloads, and parallelism.
