# Checkpoint 1 (after 5 gates: G00-G04)

Date: 2026-11-02. Procedure: charter section 5.

## 1. Original main task (re-read verbatim)

> 現在、Ubuntu 24.04を搭載したホストPC上のQEMU環境において、以下の実装を再現することを検討している。
> IBMのAssured Confidential Execution (ACE)：
> https://arxiv.org/html/2505.12995v1 / https://github.com/IBM/ACE-RISCV

In short: reproduce IBM ACE (paper arXiv:2505.12995, code IBM/ACE-RISCV) in a QEMU environment on an
Ubuntu 24.04 host, and publish the sanitized result at github.com/junlinh12.
Charter section 1 refines this into: boot OpenSBI, the ACE Security Monitor, RISC-V Linux KVM, and a
Confidential VM, and confirm local attestation and the demo secret (E1-E9).

## 2. Project requirements (re-read)

| # | Requirement | Status at checkpoint 1 |
|---|---|---|
| R1 | Sanitize personal and host information before publishing | Masked review logs; GitHub no-reply identity; commits in UTC since G03. Open for G16: root commit offset `<local offset>` (G02 F8), local times inside logs (G03 F3). |
| R2 | One Project, One Log System | All evidence in `logs/` only (renamed from `Project Logs/` by owner's decision in G01). Superseded run kept, not deleted. Logs written by upstream builds must be collected into `logs/` from G06 on. |
| R3 | Re-check the main task every 5 gates | This checkpoint. The charter scheduled it after G05, which would have been the 6th gate; corrected to after G04, G09, G14 (charter v1.3). |
| R4 | Check the host environment before starting | G00 PASS: 20 cores, 30.7 GiB RAM, 479.5 GiB free, Ubuntu 24.04.5. |
| R5 | All projects under `~/projects`; no local paths in published files | Project at `~/projects/IBM-ACE-On-QEMU-Reproduction`. Published files use `~` or `$PROJECT_ROOT` only. |

## 3. Gates since the start

| Gate | Judgement | Served |
|---|---|---|
| G00 Host baseline | PASS | R4; prerequisite for E2 |
| G01 Project skeleton | PASS | R1, R2, R5; prerequisite for E9 |
| G02 Fetch upstream at pinned commit | PASS | E1 (upstream `1ebdebf`, 3 submodules) |
| G03 Install `llvm-dev` | PASS | prerequisite for E2 (all 46 CI packages present) |
| G04 Rust `nightly-2026-03-23` | PASS | prerequisite for E2 (toolchain pinned, default unchanged) |

## 4. Drift check

Every gate served the main task or a project requirement. No work outside the scope was done.
One item touched out-of-scope material: the upstream submodule step fetched `verification/refinedrust`
(formal verification). It is fetched because the upstream procedure fetches all submodules; it is not
built or used. No other drift.

Decisions taken since the start that change the plan, all recorded: `-j2` builds (owner), `logs/`
folder name (owner), UTC commits (R1), checkpoint schedule (R3).

## 5. Open items carried forward

| Item | Gate |
|---|---|
| Second toolchain file `tools/cove_tap_tool/rust-toolchain.toml` | G05 |
| Full Makefile text: `$(CARGO)` calls, `cargo fmt`, `rm -rf`, patching of OpenSBI | G05 |
| Buildroot parallelism (`BR2_JLEVEL`) may ignore `-j2` | G05 |
| `git://` reachability for dtc; kvmtool branch head | G05 |
| Run scripts: SSH port forward on all interfaces, `kill_users_qemu()`, test success criteria | G05 |
| Root commit time zone; local times in logs | G16 |

## 6. Decision

Continue with G05 (read-only audit). Next checkpoint after G09.
