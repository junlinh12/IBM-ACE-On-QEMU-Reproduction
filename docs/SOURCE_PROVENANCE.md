# Source Provenance (success criterion E1)

Recorded in G02 on 2026-10-30. Values come from the pinned upstream commit itself.

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
| Rust | `nightly-2026-03-23`, target `riscv64gc-unknown-none-elf` | `rust-toolchain.toml` |
| CI runner | `ubuntu-24.04` | `.github/workflows/build.yml` |
| CI build order | devtools, emulator, tools, hypervisor, firmware, confidential_vms, full rebuild, `ace test` | `.github/workflows/build.yml` |

## Build-time downloads (not pinned by Git)

| Download | Declared in | Pinned by | Recorded in |
|---|---|---|---|
| riscv-gnu-toolchain release `2023.09.27` tarball (github.com/riscv-collab) | `Makefile:45` | release tag | G06 (SHA-256) |
| QEMU `$(QEMU_VERSION)` tarball (download.qemu.org) | `Makefile:82` | version variable | G05 (version), G08 (SHA-256) |
| dtc (`git://git.kernel.org/pub/scm/utils/dtc/dtc.git`) | `hypervisor/Makefile:78` | not pinned | G09 (commit) |
| kvmtool, branch `cove-integration-03072023` (github.com/wojciechozga/kvmtool) | `hypervisor/Makefile:86` | branch name | G09 (commit) |
| Sources fetched by Buildroot according to its configuration | Buildroot configuration files | per configuration | G05 (scan), G09 and G11 (record) |

## Deviations from the upstream CI

| Item | Upstream CI | This project | Effect |
|---|---|---|---|
| Submodule checkout | non-recursive | recursive | none (no nested submodules) |
| Rust default toolchain | `rustup default nightly` | default unchanged | none inside the repository: `rust-toolchain.toml` selects `nightly-2026-03-23` |
| Build parallelism | `-j8` | `-j2` | build time only |
| Expat package name | `libexpat-dev` (virtual) | `libexpat1-dev` (the real package) | none |
