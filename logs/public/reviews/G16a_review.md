# G16a Review: Publication Audit (read-only)

| Field | Value |
|---|---|
| Gate | G16a Publication Audit |
| Run | `G16a_20261104T132430Z_uYpTAo` |
| Input script SHA-256 | `f864317004ffb93cfe2cb53a1784c4ea3954cd135c254587961c68a7567d7202` (as run; see F6) |
| Raw log SHA-256 | `21bddf1fffa45b473917ed9056b639338e58e6bbbbc170d053112f81e055b11f` |
| Reviewed material | masked review log (459 lines) |
| Previous gate | G15b PASS |
| **Judgement** | **PASS as an audit** (complete inventory; no user name, host name, or home path anywhere in the history; the remaining findings are listed below and fixed in G16b) |

## Criteria

| Criterion | Evidence (step) | Result |
|---|---|---|
| Inputs and evidence intact; G15b committed | hash checks OK; `52d2c67` (1, 2) | OK |
| Inventory | 46 tracked files, 412 KB; only the G16a files untracked (3) | OK |
| Commit identities | 17 commits; all 34 author and committer addresses are the GitHub no-reply address (4) | OK |
| Commit dates | 16 commits in UTC; the root commit `a30129d` has a non-UTC offset in its author and committer dates (4) | **fix** (F1) |
| User name, host name, home path, `/home/` in the whole history | not found (5) | OK |
| Local offset in the whole history | `docs/G03_apt_packages.md`, in every commit since G03, in one sentence about the root commit (5) | **fix** (F2) |
| Commit messages | no user or host name (5) | OK |
| IPv4 addresses in the published files | only `127.0.0.1` and the emulated network `192.168.100.0/24` of the upstream run script (6) | OK |
| MAC addresses; keys and tokens | none (6) | OK |
| Passwords | only the upstream guest password `passwd`, public in the upstream repository, and prose about passwords (6) | OK |
| E-mail addresses | the no-reply address; the placeholder `GITHUB_USER@users.noreply.github.com`; `git@github.com` (6) | OK |
| Candidate evidence (`logs/review`, 47 files) | no user name, host name, or home path (all masked) (7) | OK |
| Local offset in the candidate evidence | the three checkpoints, `G02_review.md`, and the review logs of G02-G04 (7) | **fix** (F3) |
| Local times in the candidate evidence | apt history in the G03 review log (`Start-Date`, `End-Date`, `Requested-By`); `ls -l` times in the logs before G08 (7) | **fix** (F3) |
| Licenses | upstream: one `LICENSE`, Apache License 2.0; all 5 patched files carry `SPDX-License-Identifier: Apache-2.0`; the project has no LICENSE, NOTICE, or README yet (8) | **add** (F4) |
| Manifest | SHA-256 of the 46 publishable files recorded (9) | OK |

## Findings and actions

**F1. The root commit's dates reveal the host's time zone** (G02 review F8). Action (G16b): rewrite every commit's author and committer date
to `+0000`, keeping the same instant. Nothing has been pushed, so this is safe; all commit hashes change, and the map from old to new hashes
is published so that the reviews' references stay traceable.

**F2. One sentence in `docs/G03_apt_packages.md` names the offset**, in every version of the file. Removing it from the current version is
not enough, because the history would still publish it. Action: replace it in every commit during the same rewrite.

**F3. The candidate evidence needs a second sanitization step.** The masking of the harness removed the user name, host name, and home path,
but not time-zone information: the offset in prose and in `git log` output, the apt history's local times and requesting user, and `ls -l`
times printed before the harness used UTC. Action: publish sanitized copies made by `scripts/sanitize_evidence.sh`, which reads the local
offset, its compact form, the zone abbreviation, and the zone name at run time and replaces them; then audit the copies again.

**F4. License and attribution are missing.** Owner's decision: Apache License 2.0 for the project, as upstream. Action: add `LICENSE`
(copied from upstream), `NOTICE` (attribution to IBM/ACE-RISCV, not affiliated with IBM), and `README.md`.

**F5. Expected hits need no action.** `127.0.0.1`, the emulated network `192.168.100.0/24`, the upstream guest password, `git@github.com`,
and the no-reply address are part of what the project documents.

**F6. The audit's own files contained the value they searched for.** The G16a script and document searched for the local offset as a literal
string, so publishing them unchanged would publish the offset. Action: the copies committed in G16b read the offset at run time
(`env -u TZ date +%:z`) instead; the executed script stays sealed in `logs/`. Every later gate reads such values at run time only.

## Owner's decisions (recorded before G16b)

| Question | Decision |
|---|---|
| License | Apache License 2.0 (as upstream) |
| Published evidence | scripts, documents, gate reviews, checkpoints, and sanitized review logs |
| GitHub repository | created as private; switched to public by the owner after reviewing it |

## Next

G16b: commit the reviewed G16a work, back up and rewrite the history, add `LICENSE`, `NOTICE`, `README.md`, and `docs/PUBLICATION.md`,
create the sanitized evidence in `logs/public/`, and audit everything that will be pushed again.
