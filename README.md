# IBM ACE on QEMU: a Reproduction on Ubuntu 24.04

This repository documents an independent reproduction of **IBM Assured Confidential Execution (ACE)** for RISC-V
([paper: arXiv:2505.12995](https://arxiv.org/abs/2505.12995), [code: IBM/ACE-RISCV](https://github.com/IBM/ACE-RISCV)) on an
Ubuntu 24.04 host, with the RISC-V platform emulated by QEMU. It contains the scripts that were run, a document for every step, the
patches that were needed, and sanitized evidence of every run.

The reproduction builds and boots OpenSBI with the ACE security monitor, a RISC-V Linux hypervisor with KVM, and a confidential VM;
it shows the local attestation of that VM and the release of a demo secret, and a negative control in which a wrong reference value
prevents the release.

This project is not affiliated with or endorsed by IBM.

## Results

All success criteria were met on the reference host. Upstream: IBM/ACE-RISCV commit `1ebdebf4cacc04fcb83191053b4e979cbcdcb2d6`.

| ID | Criterion | Result | Where |
|---|---|---|---|
| E1 | Source reproducibility | every source pinned or recorded with its hash or commit; the QEMU tarball's hash matches two independent distributions; the Linux 6.3-rc4 tarball is built from tag `v6.3-rc4` (`197b6b60ae7b`), confirmed on kernel.org and GitHub | [`docs/SOURCE_PROVENANCE.md`](docs/SOURCE_PROVENANCE.md) |
| E2 | Build reproducibility | every component built and hashed; the firmware carries the reviewed hypervisor kernel; a rebuild two days later produced a byte-identical firmware (`fw_payload.elf` `6a41b58184c3...`) | G06-G12 |
| E3 | Platform boot | OpenSBI v1.4, the ACE security monitor (`#ACE: Initializing the CoVE security monitor`, confidential memory protected by PMP on every hart), and the Linux hypervisor boot | G13 |
| E4 | KVM | `/dev/kvm` in the emulated Linux; `kvm [1]: TSM version 4 is loaded and ready to run` | G13 |
| E5 | Confidential VM | `Creating CoVE TVM`; `#ACE: Promoting a VM to a confidential VM`; the VM boots and answers over SSH | G14 |
| E6 | Local attestation | measured `PCR4` = the TAP's reference value = the value computed on the host, `0x4e73d007ac0f79c9e476f42ead1ad1299cffc44ddd0719c690b368e22040da33` (SHA3-256); `#ACE: Attestation succeeded, fetched 1 secrets` | G14 |
| E7 | Secret retrieval | `Secret=0xc0ffeec0ffeec0ffeec0ffee` in the VM, exactly once | G14 |
| E8 | Regression tests | upstream `ace test`, unchanged: `test_attestation: success`, `test_smp: success` | G15 |
| -  | Negative control | a TAP with PCR 4 changed in its last hex digit: `Local attestation failed: LocalAttestationFailed`, no secret; the original TAP in the same boot: secret released | G15b |
| E9 | Publication audit | no personal or host information in the files or the history; dates in UTC; evidence sanitized | G16a, G16b |

What this shows is bounded: on an emulated platform, the security monitor compared the confidential VM's measurement with the reference
value and released the secret if and only if they matched, in the two cases tested. It is not a security evaluation and not a result on
RISC-V hardware.

## How the work was done

The work was split into gates (G00-G17). Each gate is one script in [`scripts/`](scripts/) and one document in [`docs/`](docs/) with
exactly the same commands. A gate's script logs every command and its output, seals the log with SHA-256, and writes a masked copy for
review; the next gate begins by checking every earlier seal, and a gate is judged from its log before the next one is written. Every
gate's judgement is in [`logs/public/reviews/`](logs/public/reviews/), and checkpoints after G04, G09, and G14 re-checked the work
against the original task.

| Gates | Content |
|---|---|
| G00-G04 | host baseline, project skeleton, upstream at the pinned commit, apt packages of the upstream CI, Rust `nightly-2026-03-23` |
| G05, G05b | audit of the upstream build and run scripts for a shared host ([`docs/SAFETY_AUDIT.md`](docs/SAFETY_AUDIT.md)); two patches |
| G06-G12 | `make devtools`, `tools`, `emulator`, `hypervisor`, `firmware`, `confidential_vms`, and the upstream "rebuild all" |
| G13-G15b | boot, attestation, upstream regression test, negative control |
| G16a, G16b | publication audit and preparation ([`docs/PUBLICATION.md`](docs/PUBLICATION.md)) |

## Changes made to run upstream on a shared host

| Change | Why | Effect on what is built |
|---|---|---|
| [`patches/0001-build-parallelism.patch`](patches/0001-build-parallelism.patch) | the build used all cores (Buildroot `BR2_JLEVEL=0`, `-j` from `nproc`) | job limit only |
| [`patches/0002-run-scripts-host-safety.patch`](patches/0002-run-scripts-host-safety.patch) | the SSH forward listened on all interfaces; the stop helpers could kill other users' QEMU; `~/.ssh/known_hosts` was changed | run scripts only |
| Rust `1.98.1` for the TAP tool (`RUSTUP_TOOLCHAIN`) | the host's `stable` had no `rustfmt`, which the TAP tool's `cargo fmt` needs | same compiler release as `stable` |
| Linux 6.3-rc4 tarball built from kernel.org Git | kernel.org's snapshot service, which Buildroot uses for release candidates, returned `502 Bad Gateway` | same source tree, commit verified |
| "rebuild all" as four `make` commands | the TAP tool and the security monitor need different Rust toolchains | same targets, same order as upstream `all` |

## Observations about the pinned upstream commit

- `make confidential_vms` copies the VM's disk into the hypervisor before it adds `ace.ko` to that disk; the upstream CI's second full
  `make` is needed (G11 F2, G12 F4).
- dtc is cloned from its default branch without a pinned commit (G11 F4).
- TAP files contain fresh randomness; compare their measurements, not their hashes (G12 F2).
- After a failed attestation the confidential VM still runs; only the secret is withheld (G15b F2).
- `run_linux_vm_qemu.sh` tries to copy the VM directory into itself (harmless, G14 F4); in daemon mode QEMU also opens VNC on
  `127.0.0.1:5900` (G15 F2).

## Reference host

Ubuntu 24.04.5 LTS, kernel 7.0.0-38-generic, x86_64 with 20 cores, 30 GiB of memory (shared with other work; builds limited to 2 jobs).
Build times: Buildroot hypervisor 14 min, confidential VM 10 min, firmware 20 s; boot to SSH 5 s; attestation test 42 s.

## Reproducing

The scripts were written for the reference host and are run in order, each after the previous gate's review:

```bash
bash scripts/G00_host_baseline.sh
bash scripts/G01_project_skeleton.sh
# ... G02 to G15b in the order of the table above
```

They expect the project at `~/projects/IBM-ACE-On-QEMU-Reproduction` and the downloaded gate files in `~/download`; G01 derives the
GitHub no-reply identity from a GitHub user name, and every gate checks the SHA-256 of the files it was given. Before reusing them,
read [`PROJECT_CHARTER.md`](PROJECT_CHARTER.md), [`docs/SAFETY_AUDIT.md`](docs/SAFETY_AUDIT.md), and the document of each gate. No script
uses `sudo` except G03, which installs one apt package.

## Evidence

| Path | Content |
|---|---|
| [`logs/public/reviews/`](logs/public/reviews/) | the judgement of every gate run and the checkpoints |
| [`logs/public/review-logs/`](logs/public/review-logs/) | the logs of every gate run, masked and sanitized ([`docs/PUBLICATION.md`](docs/PUBLICATION.md)) |
| [`logs/public/SHA256SUMS`](logs/public/SHA256SUMS) | SHA-256 of every published evidence file |
| [`logs/public/ORIGINALS.sha256`](logs/public/ORIGINALS.sha256) | SHA-256 of the private review copies they were made from |
| [`logs/public/COMMIT_MAP.txt`](logs/public/COMMIT_MAP.txt) | the commit hashes cited in the reviews and the published commits they became (G16b) |

The raw logs, the console logs of the emulated machines, and all build output stay private: they contain the host's paths and names.

## License

Apache License 2.0, as upstream; see [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE). The patches in [`patches/`](patches/) modify files of
IBM/ACE-RISCV, which are licensed under the Apache License 2.0 by IBM Corporation.
