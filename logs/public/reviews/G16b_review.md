# G16b Review: Prepare the Publication

| Field | Value |
|---|---|
| Gate | G16b Publication Prep |
| Run | `G16b_20261105T082221Z_2C36LY` |
| Input script SHA-256 | `a892d95f7e45c9a3d429df3c348f93477192b652ff46b4b24dfcdaf8d51dc2d0` |
| Raw log SHA-256 | `a573a17af8cefdb5462bb95637825f2b88aeef7f09cf3fef524a95f7985da023` |
| Reviewed material | masked review log (856 lines) |
| Previous gate | G16a PASS (audit) |
| **Judgement** | **PASS** (E9: history in UTC with one sentence replaced; license, notice, and README added; evidence sanitized; the whole history audited again with nothing found) |

## Criteria

| Criterion | Evidence (step) | Result |
|---|---|---|
| Inputs and evidence intact | 7 hash checks OK; all sealed files OK (1) | OK |
| G16a committed without the local offset | the published copy of the G16a script (`80a321b9...`) differs from the executed one (`f8643170...`); neither copy contains the offset (`test -z` holds); commit `8200344` before the rewrite (2) | OK |
| Backup | `logs/G16b_pre_rewrite_20261105T082221Z.bundle`, complete history of 18 commits, verified, read-only, SHA-256 `230cbe6feef486af4e4836542925de74a6e68ed8163236bc334e70ffb09a6641` (3) | OK |
| History rewritten as intended | the trees differ in exactly one line of `docs/G03_apt_packages.md`; commit subjects identical and in order; every date in UTC; backup references and old objects removed; one reference left, `refs/heads/main` (4) | OK |
| Root commit | `0b0bcf9`, `2026-10-30T13:08:13+00:00` (the same instant as before) (4) | OK |
| License, notice, README | `LICENSE` byte-identical to upstream's (`cmp`); `NOTICE`, `README.md`, `docs/PUBLICATION.md`, `scripts/sanitize_evidence.sh` as reviewed (5) | OK |
| Sanitized evidence | 24 reviews and checkpoints, 23 review logs; lines changed: checkpoints 1 each, `G02_review.md` 1, review logs G00 1, G02 1, G03 9, G04 1, G07 9, G16a 11; all other files unchanged (6) | OK |
| Provenance files | `ORIGINALS.sha256`, `SHA256SUMS`; `COMMIT_MAP.txt` maps all 18 reviewed hashes (`a30129d` ... `8200344`) to the published ones (`0b0bcf9` ... `0652ec4`) (6) | OK |
| `logs/public` publishable | matched by the negation `!/logs/public/**` of `.gitignore` (6) | OK |
| Publication commit | `64e2427`, 55 files added, UTC (7) | OK |
| **Audit of the whole history** | user name, host name, home path, any path under `/home`, the local offset in both forms, the zone name and abbreviation, apt history details, keys and tokens: all not found; all 8 `test` lines hold; all 38 identity fields are the no-reply address (8) | OK |
| IPv4 addresses in the published tree | `127.0.0.1` (77), the emulated network `192.168.100.0/24` (`.0`, `.1`, `.2`, `.3`, `.128`), and `0.0.0.0` (2), which is the peer column of `ss` output for the listener on `127.0.0.1:4022` in the G13 and G14 logs (8) | OK |
| Manifest | 103 files, 4.1 MB, SHA-256 of each recorded (9) | OK |
| Final state | 19 commits, all in UTC; only the G16b script and document untracked (10) | OK |

## Findings and actions

**F1. The rewrite changed nothing but what was intended.** Exactly one line of one file differs between the old and the new tree, the 18
commit subjects are unchanged, and every instant is kept. The reviews cite the old hashes; `logs/public/COMMIT_MAP.txt` translates them.

**F2. The second sanitization step was needed in four places that masking had not covered.** The G03 review log held the apt history,
the G07 log `ls -l` times from before the harness printed UTC, the G16a log quoted both, and four review records named the offset in prose.
All were replaced, and the audit of the published files found no time-zone value afterwards.

**F3. One item needed the owner's judgement before publication.** The G00 review log, `G00_review.md`, and `G15_review.md` list the TCP
ports on which the reference host was listening, and two committed documents (`docs/SAFETY_AUDIT.md`, `docs/G15_regression_test.md`) name
one of them. They identify no host, user, or address, but they show which services ran on it. Owner's decision (checkpoint 4): replace them
with `<port>` in everything published. Action: G16c.

**F4. File modes in the working tree are `600`.** The harness runs with `umask 077`, so new files are readable by the owner only. Git
records only the executable bit, so the published files get the usual modes (`644`, and `755` for `scripts/sanitize_evidence.sh`).

**F5. This gate's own review log is not yet published.** It shows the local time-zone values that the audit searched for, because the
trace prints expanded variables. G17 publishes it only through `scripts/sanitize_evidence.sh`, and audits it before the push.

## Next

Checkpoint 4 (before the push). G16c: replace the listening ports in the published material and in the history (owner's decision on F3).
G17: push to the private repository and verify what GitHub received.
