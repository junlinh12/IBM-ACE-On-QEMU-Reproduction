# Checkpoint 3 (after 15 gates: G00-G14)

Date: 2026-11-04. Procedure: charter section 5.

## 1. Original main task (re-read verbatim)

> 現在、Ubuntu 24.04を搭載したホストPC上のQEMU環境において、以下の実装を再現することを検討している。
> IBMのAssured Confidential Execution (ACE)：
> https://arxiv.org/html/2505.12995v1 / https://github.com/IBM/ACE-RISCV

Charter section 1: build and boot OpenSBI, the ACE security monitor, RISC-V Linux KVM, and a confidential VM on an emulated
RISC-V platform; confirm local attestation and the demo secret; keep complete, sealed evidence; publish only approved,
sanitized material at github.com/junlinh12.

## 2. Project requirements (re-read)

| # | Requirement | Status at checkpoint 3 |
|---|---|---|
| R1 | Sanitize personal and host information before publishing | Review logs masked; UTC commits since G03 and UTC times in logs since G08. Console logs (G13, G14) contain the build host in kernel banners and stay private. Open for G16: root commit offset `<local offset>`; local times in early logs; home paths in build output. |
| R2 | One Project, One Log System | All evidence in `logs/`: gate logs, review copies, reviews, checkpoints, and the console logs of G13 and G14, each sealed through its gate log. |
| R3 | Re-check the main task every 5 gates | This checkpoint (15 gates). Next: before G17 (publication). |
| R4 | Check the host environment before starting | G00; memory, disk, port, and running-QEMU checks before every build and boot gate. |
| R5 | All projects under `~/projects`; no local paths in published files | Unchanged. |

## 3. Gates since checkpoint 2

| Gate | Runs | Judgement | Served |
|---|---|---|---|
| G10 `make firmware` | 1 | PASS | E2: security monitor and firmware; payload = reviewed kernel |
| G11 `make confidential_vms` | 1 | PASS | E1 (dtc, kvmtool commits), E2 (VM, `ace.ko`, TAPs); upstream ordering gap found |
| G12 rebuild all | 1 | PASS | E2 complete; gap closed inside the booted image; firmware reproducible |
| G13 boot | 1 | PASS | E3, E4 |
| G14 attestation | 1 | PASS | E5, E6, E7 |

## 4. Success criteria

| ID | Criterion | State | Main evidence |
|---|---|---|---|
| E1 | Source reproducibility | met | `docs/SOURCE_PROVENANCE.md`: upstream `1ebdebf`, submodules, toolchains, QEMU (externally confirmed), Linux (commit verified), Buildroot sources, crates, dtc, kvmtool |
| E2 | Build reproducibility | met | hashes of every component; installed toolchain traced to its tarball; firmware traced to the kernel; firmware rebuilt byte-identical |
| E3 | Platform boot | met | G13: OpenSBI v1.4 banner; `#ACE: Initializing the CoVE security monitor`, memory partition and PMP per hart; Linux hypervisor |
| E4 | KVM availability | met | G13: `/dev/kvm`, `h` extension, `TSM version 4 is loaded and ready to run`; G14: KVM runs the TVM |
| E5 | Confidential VM | met | G14: `Creating CoVE TVM`, `Promoting a VM to a confidential VM`, the VM boots and answers |
| E6 | Local attestation | met | G14: measured PCR 4 = TAP reference = host measurement (`0x4e73d007...`); `Attestation succeeded` |
| E7 | Secret retrieval | met | G14: `Secret=0xc0ffeec0ffeec0ffeec0ffee`, exactly once |
| E8 | Regression tests | next | G15: upstream `ace test`, unchanged |
| E9 | Publication audit | pending | G16 |

What E6 and E7 show is bounded, as the charter says: the attestation compared the measurement with the reference and released the
secret on a match. They do not show resistance to attacks, and they are obtained on an emulated platform, not on hardware.

## 5. Drift check

Every gate since checkpoint 2 served the main task. Additions made in this period, none widening the scope:

| Addition | Why | Effect on what is reproduced |
|---|---|---|
| `RUSTUP_TOOLCHAIN=1.98.1` for `confidential_vms` and in the rebuild | the `tools` prerequisite runs `cargo fmt` (G07 cause) | none (same compiler release as `stable`) |
| Rebuild as four `make` commands | the two Rust toolchains cannot be selected in one `make` | same targets, same order as the upstream `all` |
| EXIT trap in the harness (from G11) | a shell abort must still seal the log | logging only |
| Pristine disk copy and restore (from G13) | the guest writes to its disk | every boot starts from the reviewed image |
| VM console captured, longer SSH wait (G14) | evidence for E5; nested emulation | the upstream test itself runs unchanged in G15 |

Upstream properties found and recorded, without patches: the copy-before-rebuild ordering of the VM disk (G11 F2, G12 F4), the
self-copy in `run_linux_vm_qemu.sh` (G14 F4), random TAP bytes (G12 F2), unpinned dtc (G11 F4).

## 6. Open items carried forward

| Item | Gate |
|---|---|
| Upstream regression test, judged by its result lines (not its exit code) | G15 |
| Optional, for the owner to decide: a negative control (a TAP with a wrong PCR 4 must not release the secret), which would show that the attestation can fail | after G15 |
| Root commit offset; local times in early logs; home paths and host names in build output and console logs; license notices | G16 |
| Final checkpoint before the push | before G17 |

## 7. Decision

Continue with G15. Next checkpoint before G17.
