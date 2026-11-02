# IBM-ACE-On-QEMU-Reproduction: Project Charter (v1.3)

## 1. Main task

> On a host PC running Ubuntu 24.04, build a RISC-V emulation environment based on a pinned
> commit of IBM ACE-RISCV. Build and boot OpenSBI, the ACE Security Monitor, RISC-V Linux KVM,
> and a Confidential VM, and confirm the Confidential VM's local attestation and the retrieval
> of the demo secret. For every step, keep the exact input, the full log, the result and
> artifacts, and the provenance of the source code, so that the work is a reproducible research
> result. Before publishing, audit for sensitive information, and publish only approved
> material to github.com/junlinh12.

This section is re-read at every checkpoint (after every 5 completed gates: after G04, G09, G14,
and before G17) to confirm that the work has not drifted from the main task.

**Out of scope for this stage:** porting to other boards, completing ACE's formal verification,
hardware security guarantees on real silicon, remote attestation, and reproducing every
performance evaluation in the paper.

**Upstream:** https://github.com/IBM/ACE-RISCV (Apache-2.0)
**Paper:** W. Ozga et al., "ACE: Towards A High-Assurance Isolated Virtualization Environment
for RISC-V", arXiv:2505.12995 (2025).

The paper (v1, May 2025) and the pinned commit (2026) are not from the same point in time.
Results are reported as "reproduction of commit X", not as "restoration of the paper's code".

## 2. Success criteria

| ID | Criterion | Required evidence |
|---|---|---|
| E1 | Source reproducibility | IBM commit SHA, submodule SHAs, versions of main external dependencies |
| E2 | Build reproducibility | build result, exit code, and SHA-256 of produced files for each component |
| E3 | Platform boot | boot log of OpenSBI, Security Monitor, and the Linux hypervisor |
| E4 | KVM availability | KVM usable inside the emulated RISC-V Linux |
| E5 | Confidential VM | CVM creation, boot, and running guest Linux |
| E6 | Local attestation | actual verification result and its relation to the TAP and measurements |
| E7 | Secret retrieval | demo secret retrieved, with the matching execution log |
| E8 | Regression tests | number of tests run, passed, failed, and skipped |
| E9 | Publication audit | list of published files, masking results, Git history check |

A message such as "Attestation succeeded" is evidence for E6 only. It is not treated as proof
of full memory isolation or of resistance to attacks on real hardware.

## 3. Gate roadmap

| Gate | Work | Done when |
|---|---|---|
| G00 | Host baseline audit | resources, OS, tools, packages recorded |
| G01 | Charter, project layout, Git ignore rules, local Git identity | layout and publication rules fixed |
| G02 | Fetch the pinned ACE commit, check submodules | source provenance fixed (E1) |
| G03 | Install missing Ubuntu 24.04 packages | only missing packages installed, apt history kept |
| **G04** | Rust toolchain | pinned nightly and target installed without changing the default. **Checkpoint 1** |
| G05 | Audit Makefile and run scripts for side effects (read-only), then safety patches | audit reviewed, patches applied |
| G06 | `make devtools` | RISC-V GNU toolchain verified |
| G07 | `make tools` | TAP tool and ACE CLI verified |
| G08 | `make emulator` | ACE QEMU build verified |
| **G09** | `make hypervisor` | RISC-V Linux / KVM image built. **Checkpoint 2** |
| G10 | `make firmware` | OpenSBI + Security Monitor built (E2) |
| G11 | `make confidential_vms` | Linux CVM and TAP built |
| G12 | Integrated rebuild and artifact audit | final build consistent (E2) |
| G13 | Boot the RISC-V hypervisor | OpenSBI, Linux, KVM running (E3, E4) |
| **G14** | Boot CVM, local attestation, secret | E5, E6, E7. **Checkpoint 3** |
| G15 | Integrated tests and result audit | E8 |
| G16 | Sanitization, Git history and license audit | E9 |
| G17 | Publish to GitHub | **Checkpoint 4** before the push; pushed only after explicit final approval |

## 4. Working rules

**4.1 Gate cycle.**
For each gate, a script (`scripts/Gxx_*.sh`) and a document (`docs/Gxx_*.md`) are written as a
pair. The steps in the script are plain Linux commands, identical line by line to the
document. The script is run on the host; the masked review log is uploaded; the log is
reviewed and judged; only then is the next gate written.

**4.2 Judgement.**
Each gate ends with PASS, FAIL, BLOCKED, or INCONCLUSIVE, recorded in
`logs/review/Gxx_review.md`. PASS means every check defined for the gate holds,
not merely that the commands exited with 0. Each gate begins by referring to the previous
gate's judgement.

**4.3 One Project, One Log System.**
All evidence of this project lives in `logs/` only:

- `Gxx_<UTC>_<id>.raw.log`: full transcript. Sealed with SHA-256, read-only, never published.
- `Gxx_<UTC>_<id>.input.sh`: exact copy of the script that was run.
- `Gxx_<UTC>_<id>.sha256`: seal of the two files above.
- `review/`: masked copies and gate reviews. Private until approved in G16.
- `public/`: material approved for publication in G16. The only part of `logs/` tracked by Git.

**4.4 Sanitization.**
Published material contains no home paths, local user names, host names, IP or MAC addresses,
tokens, or keys. Commits use the GitHub no-reply address, set in the repository's local Git
configuration only (the global configuration is not changed). Commits are made with `TZ=UTC0`, so
commit dates do not reveal the host's time zone; G16 normalizes any earlier commit to `+0000`.

**4.5 Upstream integrity.**
IBM sources in `upstream/` are not edited in place. Any required change is stored as a patch in
`patches/` with its reason, and applied by a gate script so that it appears in the log.

**4.6 Coexistence with other projects on the host.**
No global defaults are changed (for example `rustup default`). Tools built by ACE are always
called by absolute path. Commands that stop processes are reviewed before use (G05).

**4.7 Build parallelism.**
Every build runs with `-j2` (the upstream CI uses `-j8`). The host is shared with other experiments,
and about half of its memory was in use at G00. Builds therefore take longer than the upstream estimate.

## 5. Checkpoint procedure (after G04, G09, G14, and before G17)

1. Re-read section 1 (Main task) and section 2 (Success criteria).
2. List the gates completed since the last checkpoint and their judgements.
3. For each, state which success criterion it served. Work that serves none is drift.
4. Record the result in `logs/review/CHECKPOINT_<n>.md` before continuing.
