# Checkpoint 4 (before G17: publication)

Date: 2026-11-05. Procedure: charter section 5. This is the last checkpoint; it decides whether the repository may be pushed.

## 1. Original main task (re-read verbatim)

> 現在、Ubuntu 24.04を搭載したホストPC上のQEMU環境において、以下の実装を再現することを検討している。
> IBMのAssured Confidential Execution (ACE)：
> https://arxiv.org/html/2505.12995v1 / https://github.com/IBM/ACE-RISCV

Charter section 1: build and boot OpenSBI, the ACE security monitor, RISC-V Linux KVM, and a confidential VM on an emulated
RISC-V platform; confirm local attestation and the demo secret; keep complete, sealed evidence; publish only approved,
sanitized material at github.com/junlinh12.

## 2. Project requirements (re-read)

| # | Requirement | Status at checkpoint 4 |
|---|---|---|
| R1 | Sanitize personal and host information before publishing | G16a audit, G16b fixes: history in UTC; no user name, host name, home path, local time-zone value, apt history details, key, or token in any commit; evidence published only as sanitized copies. The host's listening ports are replaced in G16c (section 6). |
| R2 | One Project, One Log System | all evidence in `logs/`, sealed; the pre-rewrite history kept as a private bundle in `logs/`; published evidence derived from it and traceable (`ORIGINALS.sha256`, `COMMIT_MAP.txt`) |
| R3 | Re-check the main task every 5 gates | checkpoints after G04, G09, G14, and this one before G17 |
| R4 | Check the host environment before starting | G00; resource and port checks before every build and boot gate |
| R5 | All projects under `~/projects`; no local paths in published files | no home path or path under `/home` in any commit (G16b) |

## 3. Gates since checkpoint 3

| Gate | Runs | Judgement | Served |
|---|---|---|---|
| G15 upstream regression test | 1 | PASS | E8 |
| G15b negative control (owner's decision) | 1 | PASS | E6, E7: the secret is withheld when the reference does not match |
| G16a publication audit | 1 | PASS as an audit | E9: findings |
| G16b publication preparation | 1 | PASS | E9: fixes, license, README, sanitized evidence, audit |

## 4. Success criteria

| ID | State |
|---|---|
| E1-E8 | met (checkpoint 3; E8 in G15) |
| E6, E7 strengthened | G15b: with a wrong reference the security monitor reports `Local attestation failed` and releases nothing; with the original TAP, in the same boot, it releases the secret |
| E9 | met locally (G16b); G17 repeats the audit immediately before the push and verifies what GitHub received |

## 5. Drift check

Every gate since checkpoint 3 served the main task or a requirement. The negative control (G15b) was added at the owner's decision and stays
within "confirm local attestation". The publication work changed no result: the history rewrite changed one sentence and the date offsets
only (G16b F1).

Lessons recorded for later work: values that must stay private are read at run time and never written into published files (G16a F6);
sanitization rules must also match values that other commands quote after a prefix (G16b test); search patterns must not match the files
that contain them.

## 6. Owner's decisions before the push

| Item | Decision |
|---|---|
| The reference host's listening TCP ports, in the G00 and G15 evidence and in two committed documents (G16b F3) | replace them with `<port>` in everything published; G16c rewrites the two documents in the history and re-creates the public copies, reading the ports from the sealed G00 log at run time, so that no published file lists them |
| How this host authenticates to GitHub for the push | not set up yet. Proposed: a fine-grained personal access token restricted to the one repository (Contents: read and write), with a short expiry, typed at the prompt and kept in memory for the duration of the push only; nothing is written to disk and no global Git setting changes |
| The private repository `junlinh12/IBM-ACE-On-QEMU-Reproduction` | must exist and be empty (no README, `.gitignore`, or license created by GitHub) before G17 |

## 7. Decision

Continue with G16c (local only). Then G17 pushes to the private repository; the owner reviews it on GitHub and makes it public.
