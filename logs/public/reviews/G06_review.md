# G06 Review: Build the RISC-V GNU Toolchain (`make devtools`)

| Field | Value |
|---|---|
| Gate | G06 Devtools |
| Run | `G06_20261102T040430Z_BPbdDC` |
| Input script SHA-256 | `0fb65977682f3d9b2deafdb2c3b73bf07f1b150f05a5f4c495298718e4bf3321` |
| Raw log SHA-256 | `0d6c53d3934b13553f7b333af81c94efca9187c63d40283054c79fc97d9c1ffb` |
| Reviewed material | masked review log |
| Previous gate | G05b PASS |
| **Judgement** | **PASS** (E1: toolchain tarball hashed; E2: devtools built and traced to that tarball) |

## Criteria

| Criterion | Evidence (step) | Result |
|---|---|---|
| Inputs and earlier evidence intact | 4 hash checks OK; all 15 sealed files OK (1) | OK |
| Patch 0002 revision 2 matches what is applied | reverse-check OK for 0001 and 0002 rev. 2, no warning (2) | OK |
| G05b work committed in UTC | `75ed2b3`, 8 files, `+00:00` (3) | OK |
| Upstream state before the build | exactly the 5 patched files (4) | OK |
| Build settings in effect | the 7 variables of `scripts/build_env.sh` (5) | OK |
| Toolchain tarball hashed | 635,643,262 bytes, SHA-256 `cf55e236f198054355bb9c6fd9ec6e599117a06927ae4e087d12cfbf8ad2e32c` (6) | OK |
| `make -j2 devtools` succeeded | 14 s (04:05:14-04:05:28 UTC) (7) | OK |
| Installed compiler comes from the hashed tarball | `bin/riscv64-unknown-linux-gnu-gcc` and the tarball member both `e4abbafacd00761506bcb5713e1f3ad94dfe91b3afb09a9bddc0cc428324f1cb` (8) | OK |
| Toolchain matches the Buildroot configurations | GCC 12.2.0 (declared GCC 12); headers `LINUX_VERSION_CODE 330245` = 5.10.5 (declared 5.10) (8) | OK |
| Upstream tree clean apart from the patches | 5 patched files, no leftover tarball (9) | OK |
| Build output not publishable | `build/ace` matched `/build/` (9) | OK |

## Findings and actions

**F1. G05b review F7 is resolved.** The external toolchain is GCC 12.2.0 with Linux 5.10.5 headers, which is
what both Buildroot configurations declare, so Buildroot's consistency check is expected to pass in G09.

**F2. The toolchain occupies 1.5 GB** (34 programs in `bin/`). The tarball kept in `build/downloads` adds 0.6 GB.
Free disk space: 478 GB. No action.

**F3. Memory unchanged by this step.** Available memory was 12 GiB before and after; the step only downloads
and unpacks. No action.

## Next gate

G07: `make tools` (ACE command-line scripts and the TAP tool `cove-tap-tool`, built with the host's stable Rust
as declared in `tools/cove_tap_tool/rust-toolchain.toml`); record the Rust version, the crates downloaded, the
binary's SHA-256, and any change made by `cargo fmt`.
