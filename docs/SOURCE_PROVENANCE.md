# Source Provenance (success criterion E1)

Recorded in G02 on 2026-10-30 and extended in G05, G05b, G06, and G07.

## Upstream repository

| Item | Value |
|---|---|
| Repository | https://github.com/IBM/ACE-RISCV |
| License | Apache-2.0 |
| Pinned commit | `1ebdebf4cacc04fcb83191053b4e979cbcdcb2d6` |
| Commit date | 2026-10-25T11:58:16+01:00 |
| Subject | Fix attestation secret release, key naming, and tests (#144) |
| `main` at fetch time | the same commit (2026-10-30 13:08 UTC) |

The paper (arXiv:2505.12995, v1, May 2025) predates this commit.
This project reproduces the pinned commit, not the exact code state of the paper.

## Submodules

| Path | URL | Commit | Describe | Role |
|---|---|---|---|---|
| `hypervisor/buildroot` | https://github.com/buildroot/buildroot.git | `954aeb7c721bf7edd56832650e8ebfb3b5c6fbd3` | 2023.11 | root file systems (use confirmed in G05) |
| `security-monitor/opensbi` | https://github.com/riscv-software-src/opensbi.git | `92e8affb31b21ddc5d1193cf754ce644db7b460a` | v1.4-13-g92e8affb | firmware hosting the security monitor |
| `verification/refinedrust` | https://gitlab.mpi-sws.org/lgaeher/refinedrust-dev.git | `6741571f64d78223f35a62656f78cde899c7e208` | - | formal verification (out of scope) |

There are no nested submodules.

## Toolchain declared in the source

| Item | Value | Source |
|---|---|---|
| Rust (security monitor) | `nightly-2026-03-23`, target `riscv64gc-unknown-none-elf` | `rust-toolchain.toml` |
| Rust (TAP tool) | declared `stable` (floating); built with `1.98.1` = `rustc 1.98.1 (48a229cea 2026-09-01)`, equal to the host's `stable` at G07 | `tools/cove_tap_tool/rust-toolchain.toml`; G07 |
| Buildroot external toolchain | declared as GCC 12, kernel headers 5.10 | both Buildroot configurations |
| CI runner | `ubuntu-24.04` | `.github/workflows/build.yml` |
| CI build order | devtools, emulator, tools, hypervisor, firmware, confidential_vms, full rebuild, `ace test` | `.github/workflows/build.yml` |

## Build-time downloads (not pinned by Git)

| Download | Declared in | Pinned by | Recorded in |
|---|---|---|---|
| RISC-V GNU toolchain `riscv64-glibc-ubuntu-22.04-gcc-nightly-2023.09.27-nightly.tar.gz` (github.com/riscv-collab release `2023.09.27`) | `Makefile:17,45` | release tag | G06: 635,643,262 bytes, SHA-256 `cf55e236f198054355bb9c6fd9ec6e599117a06927ae4e087d12cfbf8ad2e32c`; GCC 12.2.0, headers 5.10.5 |
| QEMU 8.2.1 tarball (download.qemu.org) | `Makefile:13,82` | version | G08 (SHA-256) |
| dtc (`git://git.kernel.org/pub/scm/utils/dtc/dtc.git`) | `hypervisor/Makefile:78` | not pinned (HEAD `c22868416b8d` at G05) | G09 (commit) |
| kvmtool, branch `cove-integration-03072023` (github.com/wojciechozga/kvmtool) | `hypervisor/Makefile:86` | branch name (`177a4df3a0ff` at G05) | G09 (commit) |
| Linux 6.3-rc4, hypervisor and confidential VM | `BR2_LINUX_KERNEL_CUSTOM_VERSION_VALUE` in both Buildroot configurations | version only; Buildroot has no hash for custom versions | G09 (SHA-256) |
| QEMU for the nested confidential VM (Buildroot package) | `BR2_PACKAGE_QEMU` in the hypervisor configuration; patched by `hypervisor/patches/qemu/8.1.1/cove.patch` | Buildroot package hash | G09 (version, patch applied) |
| Other Buildroot packages (busybox, bash, dropbear, openssh client, sshpass, ...) | Buildroot configurations | Buildroot package hashes | G09, G11 |
| Rust crates (TAP tool) | `tools/cove_tap_tool/Cargo.lock` | versions and checksums | G07: 57 crates |
| Rust crates (security monitor) | `security-monitor/Cargo.lock` | versions and checksums | G10 |

## Deviations from the upstream CI

| Item | Upstream CI | This project | Effect |
|---|---|---|---|
| Submodule checkout | non-recursive | recursive | none (no nested submodules) |
| Rust default toolchain | `rustup default nightly` | default unchanged | none inside the repository: `rust-toolchain.toml` selects `nightly-2026-03-23` |
| Rust for the TAP tool | `stable` | `1.98.1` via `RUSTUP_TOOLCHAIN` | none: same release as `stable` at G07 |
| Build parallelism | `-j8` | `-j2` | build time only |
| Expat package name | `libexpat-dev` (virtual) | `libexpat1-dev` (the real package) | none |
| Upstream sources | unmodified | patches 0001 and 0002 (`patches/`, `docs/SAFETY_AUDIT.md`) | job limit; run scripts safe on a shared host |
| Build directories | inside the checkout (`build/`, `qemu/`, Buildroot `dl/`) | outside the checkout (`build/ace/`, `build/qemu-source/`, `build/dl`, `build/cargo-home`) | file locations only |
