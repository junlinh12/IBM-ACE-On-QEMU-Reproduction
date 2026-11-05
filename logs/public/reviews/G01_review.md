# G01 Review: Project Skeleton

| Field | Value |
|---|---|
| Gate | G01 Project Skeleton |
| Run | `G01_20261030T125107Z_P3Dw1C` |
| Input script SHA-256 | `92c97c3dcca2ad329d2610b41114ee99373450a8d2b8889b4b5948e23b777a5c` |
| Raw log SHA-256 | `f3d39c21dee8b514be14cbe6043d84de044f0e83894b17c94f66cdcfeffd6b2d` |
| Previous gate | G00 PASS |
| **Judgement** | **PASS** |

## Criteria

| Criterion | Evidence (step) | Result |
|---|---|---|
| Inputs are the delivered files | 4 hash checks OK; G01 script and document hashes match the delivered files (1) | OK |
| G00 evidence intact after the folder rename | `Project Logs/` renamed to `logs/`; G00 raw log and input script match their seal (1) | OK |
| Layout created | `scripts/ docs/ patches/ upstream/ build/ logs/public/` (2, 7) | OK |
| Charter, scripts, documents installed | all copies succeeded (3, 7) | OK |
| Ignore rules deny by default | `.gitignore` content as specified (4) | OK |
| Local Git identity uses the no-reply address | `user.email=238169016+junlinh12@users.noreply.github.com`, local config only (5) | OK |
| Private evidence is not publishable | `check-ignore` matched all 4 test paths (6) | OK |
| Publishable set is exactly as designed | `git add --dry-run` listed the 7 expected files and nothing else (6) | OK |
| Nothing staged or committed | `git status` shows only untracked entries (6) | OK |

## Findings and actions

**F1. An earlier, unreviewed G00 run is present in `logs/`.**
`ACE-G00-Host-Baseline-20261030T115047Z-a1SbSFY1.{input.sh,raw.log,raw.log.sha256}` was produced at
11:50 UTC by an earlier audit script (v2 or v2.1). It was never uploaded or reviewed.
Action: keep it unchanged as a superseded run (evidence is never deleted). G02 re-checks its seal and
records the hash of its input script, which identifies the script version.
The reviewed G00 run is `G00_20261030T122505Z_7St35c`.

**F2. Trace order of pipelines is not strictly sequential.**
In step 1, the trace of `echo ... | sha256sum -c -` sometimes prints the two halves in reverse order.
This is how Bash traces the members of a pipeline running in parallel; the results are correct. No action.

**F3. The GitHub numeric ID appears in the log and in future commits.**
The no-reply address contains the public account ID by design. It contains no personal information
from the host. No action.

## Next gate

G02: commit the G00-G01 work locally, then fetch IBM ACE-RISCV at the pinned commit
`1ebdebf4cacc04fcb83191053b4e979cbcdcb2d6`, fetch its submodules, and record the source provenance (E1).
