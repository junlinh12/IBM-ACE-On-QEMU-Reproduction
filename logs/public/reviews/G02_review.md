# G02 Review: Fetch Upstream at the Pinned Commit

| Field | Value |
|---|---|
| Gate | G02 Fetch Upstream |
| Run | `G02_20261030T130813Z_vP2nrT` |
| Input script SHA-256 | `b926ff1077874f0699b99454a0cd00560693700f01c6753a934438b257d2bd95` |
| Raw log SHA-256 | `82e1212569e91308dc7699a1cbf0050a9ef2b8ebd3bbbd5bdb4017666372c0bd` |
| Previous gate | G01 PASS |
| **Judgement** | **PASS** (E1: upstream and submodules pinned; build-time downloads recorded in later gates) |

## Criteria

| Criterion | Evidence (step) | Result |
|---|---|---|
| Inputs and earlier evidence intact | G01 review hash OK; all 5 sealed files OK (1) | OK |
| G00-G01 work committed locally | root commit `a30129d`, 7 files, author `junlinh12 <238169016+junlinh12@users.noreply.github.com>` (2) | OK, see F8 |
| Upstream cloned over HTTPS | clone succeeded in about 1 s (3) | OK |
| Pinned commit checked out | `HEAD = 1ebdebf4cacc04fcb83191053b4e979cbcdcb2d6`, working tree clean (4) | OK |
| Submodules at required commits | 3 submodules, all lines start with a space, no nested submodules (5, 6) | OK |
| Build inputs recorded | `rust-toolchain.toml`, CI workflow, 4 external URLs in Makefiles (7) | OK |
| Upstream not publishable by this project | `upstream/ACE-RISCV` matched `/upstream/` (8) | OK |
| Project tree as expected | only the 2 new G02 files untracked (8) | OK |

## Findings and actions

**F1. Pin confirmed.** `1ebdebf` ("Fix attestation secret release, key naming, and tests (#144)",
2026-10-25) was still `origin/main` at 2026-10-30 13:08 UTC.

**F2. Submodules.**
`hypervisor/buildroot` at `954aeb7c` (2023.11), `security-monitor/opensbi` at `92e8affb`
(v1.4-13-g92e8affb), `verification/refinedrust` at `6741571f` (gitlab.mpi-sws.org).
The CI checks out submodules non-recursively; there are no nested submodules, so the content is identical.
`verification/refinedrust` belongs to the formal verification, which is out of scope; its use by the
functional build is checked in G05. Total size 299 MB, submodule fetch 21 s.

**F3. `llvm-dev` is required.** The CI step "install OpenSBI dependencies" installs
`clang libclang-dev llvm-dev`. Action: G03 installs `llvm-dev`. Every other CI package was present in G00
(the CI name `libexpat-dev` is the virtual name of the installed `libexpat1-dev`).

**F4. Rust nightly confirmed: `nightly-2026-03-23`** with target `riscv64gc-unknown-none-elf`.
This verifies the external audit's value. The CI runs `rustup default nightly`, but inside the repository
`rust-toolchain.toml` overrides the default, so the pinned nightly is what builds the code.
Action: G04 installs `nightly-2026-03-23` with the target and `rustfmt` (added by the CI) without changing
the default toolchain. `cargo-binutils` is in the README but not in the CI; G04 checks whether the Makefiles use it.

**F5. Parallelism deviates from CI.** CI uses `-j8`; this project uses `-j2` (owner's decision, charter 4.7).
This affects build time only.

**F6. Build-time downloads are not pinned by Git.**

| Download | Declared in | Pinned by | Action |
|---|---|---|---|
| riscv-gnu-toolchain release 2023.09.27 tarball | `Makefile:45` | release tag | G06: record SHA-256 |
| QEMU `$(QEMU_VERSION)` tarball, download.qemu.org | `Makefile:82` | version variable | G05: read version; G08: record SHA-256 |
| dtc, `git://git.kernel.org/.../dtc.git` | `hypervisor/Makefile:78` | nothing (default branch) | G05: check `git://` reachability; G09: record commit |
| kvmtool, branch `cove-integration-03072023` of `wojciechozga/kvmtool` | `hypervisor/Makefile:86` | branch name (can move) | G09: record commit |

Buildroot may download further sources (for example the Linux kernel) according to its configuration
files, which the Makefile scan does not cover. Action: G05 scans the configuration files.

**F7. Superseded run identified.** The input script of
`ACE-G00-Host-Baseline-20261030T115047Z-a1SbSFY1` has SHA-256 `a96ca97b...`, which is audit script v2.1.
Its seal is intact. It stays as a superseded, unreviewed run.

**F8. The root commit records the local time zone.** The author date of `a30129d` is
`<local time>`. A published commit date would reveal the host's time zone.
Action: from G03 on, every commit is made with `TZ=UTC0`. Before publication, G16 rewrites the time-zone
offset of earlier commits to `+0000` (the instant in time is unchanged; commit hashes change, which is
harmless because nothing has been pushed). Charter 4.4 is updated accordingly.

## Next gate

G03: install `llvm-dev` only, after a simulation shows that no installed package would be removed or upgraded.
