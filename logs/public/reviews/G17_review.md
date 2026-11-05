# G17 Review: Publish to the Private GitHub Repository

| Field | Value |
|---|---|
| Gate | G17 Publish |
| Run | `G17_20261105T085347Z_JVIZF8` |
| Input script SHA-256 | `5a4fcb1ba53c3d689ef673b75fdbb1018b9128787ee8de8386ad73c553d6af12` |
| Raw log SHA-256 | `10cf51769c466b5b436893124ca351d2a0618f2492ec43f2a37ee3c49b33b896` |
| Reviewed material | masked review log (430 lines); no token-like string in it |
| Previous gate | G16c PASS |
| **Judgement** | **PASS** (the audited history was pushed to the private repository; GitHub holds exactly the audited commit; the token was forgotten; the repository is still private) |

## Criteria

| Criterion | Evidence (step) | Result |
|---|---|---|
| Inputs and evidence intact | 4 hash checks OK, including the published copy of the G16c document; all sealed files OK (1) | OK |
| New gate files clean | no local time-zone value and no listening port in the G16c and G17 scripts and documents (2) | OK |
| Evidence and commit | 27 reviews and checkpoints, 25 review logs re-created; commit `b11c247`, UTC (2) | OK |
| **Final audit** | only allowed paths tracked; no listening port, no sentence naming one, no port line in the published logs; no user name, host name, home path, path under `/home`, local time-zone value, apt history detail, key, or token in any commit; every date in UTC; every identity the no-reply address; `SHA256SUMS` matches; all 13 `test` lines hold (3) | OK |
| Size | 114 tracked files; the largest are the review logs of G09 (2.3 MB), G11 (0.6 MB), and G05 (0.1 MB) (3) | OK |
| Not public before the push | anonymous API request: `404` (4) | OK |
| Remote and credentials | `origin` set in the local configuration only; no credential helper configured; no prompt override in the environment (5) | OK |
| Login and empty repository | login and read succeeded; 0 references on GitHub (6) | OK |
| Push | ordinary push, `* [new branch] main -> main`; `main` tracks `origin/main` (7) | OK |
| **GitHub holds the audited commit** | one branch; `refs/heads/main` = `HEAD` = `b11c247276c47c057014abca1c78e0c2882519d7`; status `## main...origin/main` (8) | OK |
| Token forgotten; still private | `git credential-cache exit`; anonymous request again `404`; credential helpers unchanged (9) | OK |
| Published state | 22 commits; working tree clean (10) | OK |

## Findings

**F1. GitHub received exactly what was audited.** A Git commit hash covers the whole tree and history, so the equality of the remote and local
`HEAD` means that the 22 commits and 114 files on GitHub are the ones audited in step 3.

**F2. The token never reached a file or a log.** It was typed at git's prompt, held by `credential-cache` in memory, and erased in step 9;
the review log contains no token-like string, and no credential helper was configured before or after.

**F3. This gate's own log and this review are not in the published history.** They were created after the push; they stay private in
`logs/`, like every raw log.

## Remaining steps for the owner

1. Review the repository on GitHub.
2. Make it public: repository Settings, General, Danger Zone, Change visibility, Public.
3. Delete the fine-grained token.
