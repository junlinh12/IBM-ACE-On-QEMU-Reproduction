# Source Provenance (success criterion E1)

Recorded in G02 on 2026-10-30 and extended in G05 to G09.

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
| Buildroot external toolchain | `BR2_TOOLCHAIN_EXTERNAL=y` without a custom toolchain, so Buildroot uses Bootlin's prebuilt toolchain; the GCC 12 / headers 5.10 lines apply only to a custom toolchain | both Buildroot configurations; G09 |
| CI runner | `ubuntu-24.04` | `.github/workflows/build.yml` |
| CI build order | devtools, emulator, tools, hypervisor, firmware, confidential_vms, full rebuild, `ace test` | `.github/workflows/build.yml` |

## Build-time downloads (not pinned by Git)

| Download | Declared in | Pinned by | Recorded in |
|---|---|---|---|
| RISC-V GNU toolchain `riscv64-glibc-ubuntu-22.04-gcc-nightly-2023.09.27-nightly.tar.gz` (github.com/riscv-collab release `2023.09.27`) | `Makefile:17,45` | release tag | G06: 635,643,262 bytes, SHA-256 `cf55e236f198054355bb9c6fd9ec6e599117a06927ae4e087d12cfbf8ad2e32c`; GCC 12.2.0, headers 5.10.5 |
| QEMU 8.2.1 tarball (download.qemu.org) | `Makefile:13,82` | version | G08: 129,848,448 bytes, SHA-256 `8562751158175f9d187c5f22b57555abe3c870f0325c8ced12c34c6d987729be`, equal to the hashes pinned by Chimera Linux and nixpkgs |
| dtc (`git://git.kernel.org/pub/scm/utils/dtc/dtc.git`) | `hypervisor/Makefile:78` | not pinned (HEAD `c22868416b8d` at G05) | G09 (commit) |
| kvmtool, branch `cove-integration-03072023` (github.com/wojciechozga/kvmtool) | `hypervisor/Makefile:86` | branch name (`177a4df3a0ff` at G05) | G09 (commit) |
| Linux 6.3-rc4, hypervisor and confidential VM | `BR2_LINUX_KERNEL_CUSTOM_VERSION_VALUE` in both Buildroot configurations | version only; Buildroot has no hash for custom versions | G09: see "Linux source" below |
| QEMU for the nested confidential VM (Buildroot package) | `BR2_PACKAGE_QEMU` in the hypervisor configuration | Buildroot package hash | G09: QEMU 8.1.1, `qemu-8.1.1.tar.xz` SHA-256 `37ce2ef5e500fb752f681117c68b45118303ea49a7e26bd54080ced54fab7def`; `hypervisor/patches/qemu/8.1.1/cove.patch` applied |
| Buildroot external toolchain | Buildroot's default for `BR2_TOOLCHAIN_EXTERNAL=y` (no custom toolchain selected) | Buildroot package hash | G09: Bootlin `riscv64-lp64d--glibc--bleeding-edge-2023.08-1.tar.bz2`, SHA-256 `9eda527aea5ce7da27957c3b8e4adb65430be046b713dca25432a09cb6675976` |
| Other Buildroot packages (busybox 1.36.1, bash, dropbear 2022.83, sshpass 1.10, ...) | Buildroot configurations | Buildroot package hashes | G09: 46 source files in 45 package directories hashed (hypervisor); G11 (confidential VM) |
| Rust crates (TAP tool) | `tools/cove_tap_tool/Cargo.lock` | versions and checksums | G07: 57 crates |
| Rust crates (security monitor) | `security-monitor/Cargo.lock` | versions and checksums | G10 |

## Linux source

Buildroot 2023.11 downloads a release candidate from cgit's on-demand snapshot,
`https://git.kernel.org/torvalds/t/linux-6.3-rc4.tar.gz`. On 2026-11-02 this URL redirected to
`.../linux.git/snapshot/linux-6.3-rc4.tar.gz`, which returned `502 Bad Gateway` (G09 first run and step 5 of the second run).
G09 therefore built the same source from kernel.org's Git service:

| Item | Value |
|---|---|
| Repository | `https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git` |
| Tag and commit | `v6.3-rc4` = `197b6b60ae7bc51dd0814953c562833143b292aa` (2023-03-26, "Linux 6.3-rc4") |
| Commit confirmed by | kernel.org tag, GitHub mirror tag, and the commit ID stored in the tarball (all equal) |
| Tarball | `git archive --format=tar.gz --prefix=linux-6.3-rc4/ v6.3-rc4`; 223,281,349 bytes, SHA-256 `3c35981844236716b0a69742bab9656e53d6f4b576cc6bc5cd05fcce126e2a10` |
| Placed at | `build/dl/linux/linux-6.3-rc4.tar.gz`, where Buildroot looks before downloading |

The tarball's SHA-256 can differ between Git versions; the commit ID is the value to compare.

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
| Linux 6.3-rc4 source | cgit snapshot downloaded by Buildroot | the same tag archived from kernel.org Git and placed in `build/dl` | none on the source tree (commit verified) |
