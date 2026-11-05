# Checkpoint 2 (after 10 gates: G00-G09)

Date: 2026-11-02. Procedure: charter section 5.

## 1. Original main task (re-read verbatim)

> 現在、Ubuntu 24.04を搭載したホストPC上のQEMU環境において、以下の実装を再現することを検討している。
> IBMのAssured Confidential Execution (ACE)：
> https://arxiv.org/html/2505.12995v1 / https://github.com/IBM/ACE-RISCV

Charter section 1: build and boot OpenSBI, the ACE security monitor, RISC-V Linux KVM, and a confidential VM on an emulated
RISC-V platform; confirm local attestation and the demo secret; keep complete, sealed evidence; publish only approved,
sanitized material at github.com/junlinh12.

## 2. Project requirements (re-read)

| # | Requirement | Status at checkpoint 2 |
|---|---|---|
| R1 | Sanitize personal and host information before publishing | Review logs masked; UTC commits; since G08 the harness prints UTC times (A17). Build outputs embed the home path and are never published (G09 F6). Open for G16: root commit offset `<local offset>`; local times in earlier logs (G03 apt history, G06/G07 `ls -l`). |
| R2 | One Project, One Log System | All evidence in `logs/`, including 4 stopped or blocked runs (G07 run 1, G08 runs 1-2, G09 run 1), kept and sealed. Build output (Buildroot, QEMU, cargo) goes into the gate logs, not into separate log files. |
| R3 | Re-check the main task every 5 gates | This checkpoint (10 gates). Next: after G14. |
| R4 | Check the host environment before starting | Done in G00; since G08 each build gate also checks memory (A16) and, since G09, disk. |
| R5 | All projects under `~/projects`; no local paths in published files | Unchanged; all scripts and documents use `$PROJECT_ROOT` or `~`. |

## 3. Gates since checkpoint 1

| Gate | Runs | Judgement | Served |
|---|---|---|---|
| G05 Audit of build and run scripts | 1 | PASS | safety on the shared host; A1-A15 |
| G05b Safety patches | 1 | PASS | patches 0001 (job limit) and 0002 (SSH on 127.0.0.1, no foreign kills) |
| G06 `make devtools` | 1 | PASS | E1, E2 (toolchain traced to its tarball) |
| G07 `make tools` | 2 (run 1 BLOCKED: no `rustfmt` for stable) | PASS | E2 (TAP tool with Rust 1.98.1, shared `stable` unchanged) |
| G08 `make emulator` | 3 (runs 1-2 stopped: inputs not downloaded) | PASS | E1 (QEMU source confirmed by two distributions), E2 |
| G09 `make hypervisor` | 2 (run 1 BLOCKED: kernel.org snapshot 502) | PASS | E1 (Linux source verified by commit), E2, prerequisite for E3-E4 |

## 4. Success criteria so far

| ID | State |
|---|---|
| E1 Source reproducibility | upstream commit, submodules, toolchain, QEMU, Linux, 46 Buildroot sources, 57 crates recorded |
| E2 Build reproducibility | devtools, tools, emulator, hypervisor images hashed; firmware and confidential VM next (G10, G11) |
| E3-E8 | not started (boot and test gates G13-G15) |
| E9 Publication audit | prepared: deny-by-default `.gitignore`, masked logs, UTC; executed in G16 |

## 5. Drift check

Every gate since checkpoint 1 served the main task or a project requirement. Three additions were needed to keep going
and stay within the rules; none widens the scope:

| Addition | Why | Effect on what is reproduced |
|---|---|---|
| Patches 0001 and 0002 | the shared host (job limit, network exposure, process kills) | none on the built code; recorded in `patches/` |
| Rust 1.98.1 for the TAP tool | shared `stable` had no `rustfmt` | same compiler release as `stable`; checked |
| Linux 6.3-rc4 tarball built from kernel.org Git | the snapshot service returned 502 | same source tree; commit checked on kernel.org and GitHub |

Corrections made since checkpoint 1: G06 review F1 (Buildroot uses Bootlin's toolchain, not the one from G06); checkpoint
schedule (charter v1.3). The out-of-scope `verification/refinedrust` submodule is still unused.

## 6. Open items carried forward

| Item | Gate |
|---|---|
| Record the Bootlin compiler version (G09 F5) | G10 |
| Security monitor: `cargo fmt` result, OpenSBI patch state, crates | G10 |
| dtc and kvmtool commits (cloned by `make confidential_vms`) | G11 |
| Test time limits inside the hypervisor (G05b F4) | G14-G15 |
| Root commit offset; local times in earlier logs; home paths in build output | G16 |

## 7. Decision

Continue with G10 (`make firmware`). Next checkpoint after G14.
