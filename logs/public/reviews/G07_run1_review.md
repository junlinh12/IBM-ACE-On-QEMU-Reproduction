# G07 Review, first run: Build the ACE Tools (`make tools`)

| Field | Value |
|---|---|
| Gate | G07 Tools, first run |
| Run | `G07_20261102T041114Z_vzwQUZ` |
| Input script SHA-256 | `d87e48892483b98919271a837d20c51344a6d1cb4bf3d92ab722f9cb51cb37c7` |
| Raw log SHA-256 | `9ec4d8bc7e9af4b6fe1d060096a91634672fa2ed985aa651c01fc031d4e17d06` |
| Reviewed material | masked review log |
| Previous gate | G06 PASS |
| **Judgement** | **BLOCKED** (a precondition is missing; detected before anything was built) |

## What happened

| Step | Result |
|---|---|
| 1. Inputs and earlier evidence | G06 review hash OK; all 17 sealed files OK |
| 2. Commit of the G06 work | `1e7d46d`, 2 files, `+00:00` |
| 3-4. Host state, build settings | kernel 7.0.0-38; 12 GiB available; the 7 build variables in effect |
| 5. Rust toolchain for the TAP tool | `stable` = `rustc 1.98.1 (48a229cea 2026-09-01)`; `cargo fmt --version` failed: `'cargo-fmt' is not installed for the toolchain 'stable-x86_64-unknown-linux-gnu'` |
| 6-9 | not run; the gate stopped at step 5 as designed |

The TAP tool's Makefile runs `cargo fmt` before building (`tools/cove_tap_tool/Makefile:23,41-42`), so
`make tools` would have failed. The check in step 5 existed for this case. Nothing was built and no file
outside `logs/`, `scripts/`, and `docs/` was changed.

## Decision

| Option | Shared environment | Reproducibility |
|---|---|---|
| A. `rustup component add rustfmt --toolchain stable` | changes the `stable` toolchain used by other projects | keeps the floating `stable` (SAFETY_AUDIT A13) |
| **B. Install toolchain `1.98.1` (with `rustfmt`) and select it for `make tools` only, with `RUSTUP_TOOLCHAIN=1.98.1`** | unchanged: `stable` and the default are not touched | pins the TAP tool to an exact Rust version |

Chosen: **B**, following charter 4.6 (no change to shared tools) and resolving A13. `RUSTUP_TOOLCHAIN` takes
precedence over `rust-toolchain.toml` and applies only to the commands it is set for; `make tools` builds only
the TAP tool, so the security monitor's pinned nightly is unaffected. The second run checks that the selected
compiler prints exactly the same version line as the host's `stable`, so the TAP tool is built with the same
Rust release that the upstream `rust-toolchain.toml` would select today, and checks afterwards that `stable`
still has no `rustfmt`.

## Next

G07, second run: install toolchain `1.98.1`, then `make tools` as planned.
