# G16c Review: Replace the Listening Ports in Everything Published

| Field | Value |
|---|---|
| Gate | G16c Port Masking |
| Run | `G16c_20261105T084451Z_h6Y0OI` |
| Input script SHA-256 | `d4bf32e18a2abe3a53e6ac169d685ad653102423b431d12385cb5f52295a3052` |
| Raw log SHA-256 | `cadf2debe9792dd5f8d4cd44d05367e283a053c14becfdc53746af2cdf0b9aaa` |
| Reviewed material | masked review log (881 lines) |
| Previous gate | G16b PASS; checkpoint 4 recorded |
| **Judgement** | **PASS** (the reference host's listening ports are replaced in the history and in the published evidence; the whole history audited again with nothing found) |

## Criteria

| Criterion | Evidence (step) | Result |
|---|---|---|
| Inputs and evidence intact | 5 hash checks OK; all sealed files OK (1) | OK |
| G16b gate files committed without a time-zone value | both `test -z` hold; `35fbd8a` before the rewrite (2) | OK |
| Ports read without printing them | from the sealed G00 raw log into `build/private/` (ignored by Git); only the counts are printed: 5 ports, 2 of them from 1024 upward (3) | OK |
| Backup | `logs/G16c_pre_rewrite_20261105T084451Z.bundle`, complete history of 20 commits, verified, read-only, SHA-256 `515502315e1418d344eb9d4e1e754281017f5a5750ac178e28088f665ff443c9` (4) | OK |
| History rewritten as intended | outside `logs/public` exactly one line of `docs/SAFETY_AUDIT.md` and one of `docs/G15_regression_test.md` differ; inside, only line replacements (G00 review log 5, G15 review log 1, `G00_review.md` 1, `G15_review.md` 1, `SHA256SUMS` 4); commit subjects unchanged and in order; every date in UTC; one reference left (5) | OK |
| Evidence re-created | 26 reviews and checkpoints, 24 review logs (the new ones: the G16b review log, `G16b_review.md`, `CHECKPOINT_4.md`); lines changed by sanitization listed for 14 files (6) | OK |
| Commit map | `COMMIT_MAP.txt` with three hash columns for all 20 rewritten commits: as cited in the reviews (`a30129d` ... `8200344`), after G16b (`0b0bcf9` ... `35fbd8a`), and published (`0b0bcf9` ... `9f70217`); commits before G05b kept their hashes (6) | OK |
| Commit | `cc96cec`: sanitization script revision 2 and the updated evidence (7) | OK |
| **Audit of the whole history** | no listening port from 1024 upward as a word; no sentence naming a listening port; no number-only line after an `ss -ltnH` pipeline in the published logs; user name, host name, home path, any path under `/home`, the local offset in both forms, the zone name and abbreviation, apt history details, keys and tokens: all not found; all 11 `test` lines hold; `SHA256SUMS` matches; all 42 identity fields are the no-reply address (8) | OK |
| Final state | 21 commits, all in UTC; only the G16c script and document untracked (10) | OK |

## Findings and actions

**F1. The history needed the same treatment as the evidence.** The G16b commit had already committed the public evidence before the ports were
replaced; rewriting only the two documents would have left the ports in the published history. The tree filter therefore also rewrote the
evidence in every commit that contains it and recomputed `SHA256SUMS` there, so every commit is consistent in itself.

**F2. Every changed line is a replacement.** In the evidence, the number of added and removed lines is equal for every file, and outside the
evidence only the two intended lines changed.

**F3. The hashes cited in the reviews remain traceable.** Commits up to G05 kept their hashes; for all later ones `logs/public/COMMIT_MAP.txt`
gives the hash cited in the reviews, the hash after G16b, and the published hash.

**F4. This gate's own log, review, and script are not yet in the published history.** G17 commits them, sanitized, before the push.

**F5. The published copy of this gate's document is revised in its prose.** A sentence of `docs/G16c_port_masking.md` that explained the apt
pattern quoted the field name followed by a colon and a space, which the strict apt check of G17 would match. Found in the test of G17; the
copy that G17 commits says the same in other words. The commands are unchanged, and the executed script stays sealed in `logs/`.

## Next

G17: commit the G16c work and this review, audit once more, push to the private repository with a token typed at the prompt, and verify what
GitHub received.
