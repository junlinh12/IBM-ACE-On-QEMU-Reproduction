# G16c: Replace the Listening Ports in Everything Published

The G00 evidence lists the TCP ports on which the reference host was listening, and two committed documents name one of them (G16b review
F3). They identify no host, user, or address, but they show which services ran on the host. The owner decided to replace them with `<port>`
in everything published (checkpoint 4). This gate does that, in the history and in the public evidence, and audits again. It changes the
local repository only; nothing is pushed.

Previous gate: **G16b PASS**; checkpoint 4 recorded.

The same commands are run, with logging, by [`scripts/G16c_port_masking.sh`](../scripts/G16c_port_masking.sh).

**No port number is written into this gate's files**, and none into the sanitization script: the ports are read from the sealed G00 log at
run time into a private file under `build/`, and passed to the tools by its path. The same holds for the local time-zone values (G16b).

**This gate rewrites the Git history once more.** All commit hashes from G05b on change. The history before the rewrite is saved to a private
bundle; `logs/public/COMMIT_MAP.txt` maps every cited hash to the published one. Nothing has been pushed yet.

Set the paths first:

```bash
PROJECT_ROOT=~/projects/IBM-ACE-On-QEMU-Reproduction
DOWNLOAD_DIR=~/download
```

## 1. Verify the downloaded files and all sealed evidence

```bash
cd "$DOWNLOAD_DIR"
sha256sum G16c_port_masking.sh G16c_port_masking.md
echo "ec1db4f19d5251c49edc330520dc0a6b07ed33ac7bd7530c829106564b450ac1  G16b_review.md" | sha256sum -c -
echo "e59f9938ab31eb01c9c2cea12a1ce0007b0fa3e4ceabe9c3a075ee0680557461  CHECKPOINT_4.md" | sha256sum -c -
echo "0c9eee3c401f75ec5fcfb3b9cb745fda69c8bf91bd40db73d80713981086815f  sanitize_evidence.sh" | sha256sum -c -
cd "$PROJECT_ROOT/logs"
sha256sum -c *.sha256
```

Expected: every line ends with `OK`. `sanitize_evidence.sh` is revision 2, with the port rules. If any check fails, stop.

## 2. Commit the reviewed G16b work (local only, UTC)

```bash
cd "$PROJECT_ROOT"
cp "$DOWNLOAD_DIR/G16b_review.md" logs/review/
cp "$DOWNLOAD_DIR/CHECKPOINT_4.md" logs/review/
test -z "$(grep -F -e "$(env -u TZ date +%:z)" -e "$(env -u TZ date +%z)" -e "$(timedatectl show -p Timezone --value)" scripts/G16b_publication_prep.sh docs/G16b_publication_prep.md)"
test -z "$(grep -w -F -e "$(env -u TZ date +%Z)" scripts/G16b_publication_prep.sh docs/G16b_publication_prep.md)"
git add scripts/G16b_publication_prep.sh docs/G16b_publication_prep.md
git status --short
git diff --cached --quiet || TZ=UTC0 git commit -m "G16b: publication preparation (gate script and document)"
git log -1 --format='%h  %aI  %an <%ae>  %s'
cp "$DOWNLOAD_DIR/G16c_port_masking.sh" scripts/
cp "$DOWNLOAD_DIR/G16c_port_masking.md" docs/
```

The G16b script and document are committed. Like every published file, they must contain no local time-zone value; the two `test`
lines read the values at run time (`env -u TZ date`, `timedatectl`) and fail if either file contains one.

## 3. Read the listening ports from the sealed G00 log into a private file

```bash
PORTS="$PROJECT_ROOT/build/private/listening-ports.txt"
mkdir -p "$PROJECT_ROOT/build/private"
awk '/^\$ ss -ltnH$/ {f = 1; next} f && /^\$ / {next} f && /^[0-9]+$/ {print; next} f {exit}' logs/G00_20261030T122505Z_7St35c.raw.log > "$PORTS"
awk '$1 >= 1024' "$PORTS" > "$PROJECT_ROOT/build/private/listening-ports-high.txt"
wc -l < "$PORTS"
wc -l < "$PROJECT_ROOT/build/private/listening-ports-high.txt"
test "$(wc -l < "$PORTS")" -ge 1
git check-ignore -q build/private/listening-ports.txt
```

The listening ports are read from the sealed raw log of G00 (step 8 of G00 printed them, one per line, after `$ ss -ltnH`) into
`build/private/`, which is never published (`.gitignore`). Only their count is printed, so the values appear in no log; the ports from 1024
upward go into a second file for the audit in step 8, because numbers that small are common in other text. The gate stops if no port was
found.

## 4. Back up the history and record the commits before the rewrite

```bash
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BUNDLE="$PROJECT_ROOT/logs/G16c_pre_rewrite_$STAMP.bundle"
git bundle create "$BUNDLE" --all
git bundle verify "$BUNDLE"
chmod 400 "$BUNDLE"
sha256sum "$BUNDLE"
git log --reverse --format='%h %s' > "$PROJECT_ROOT/build/g16c-commits-before.txt"
wc -l < "$PROJECT_ROOT/build/g16c-commits-before.txt"
```

As in G16b: the complete history before this rewrite is kept in a private bundle in `logs/`, sealed through this gate's log.

## 5. Rewrite the history: the port mentions in two documents

```bash
export SANITIZER="$DOWNLOAD_DIR/sanitize_evidence.sh"
export PORTS_FILE="$PORTS"
OLD_HEAD="$(git rev-parse HEAD)"
FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch -f --tree-filter 'for f in docs/SAFETY_AUDIT.md docs/G15_regression_test.md logs/public/reviews/* logs/public/review-logs/*; do if [ -f "$f" ]; then bash "$SANITIZER" --ports "$PORTS_FILE" < "$f" > "$f.tmp" && mv "$f.tmp" "$f"; fi; done; if [ -d logs/public/reviews ]; then (cd logs/public && find reviews review-logs -type f | sort | xargs sha256sum) > logs/public/SHA256SUMS; fi' -- --all
git diff --numstat "$OLD_HEAD" HEAD
test "$(git diff --numstat "$OLD_HEAD" HEAD -- . ':(exclude)logs/public')" = "$(printf '1\t1\tdocs/G15_regression_test.md\n1\t1\tdocs/SAFETY_AUDIT.md')"
test -z "$(git diff --numstat "$OLD_HEAD" HEAD -- logs/public | awk '$1 != $2')"
git update-ref -d refs/original/refs/heads/main
git reflog expire --expire=now --all
git gc --prune=now --quiet
git for-each-ref
git log --reverse --format='%h %s' > "$PROJECT_ROOT/build/g16c-commits-after.txt"
test "$(cut -d' ' -f2- "$PROJECT_ROOT/build/g16c-commits-before.txt" | sha256sum)" = "$(cut -d' ' -f2- "$PROJECT_ROOT/build/g16c-commits-after.txt" | sha256sum)"
test "$(git log --format='%aI%n%cI' | grep -c -v '+00:00$')" -eq 0
git status --short
```

The tree filter passes, in every commit, `docs/SAFETY_AUDIT.md`, `docs/G15_regression_test.md`, and the public evidence committed in
G16b (`logs/public/reviews/`, `logs/public/review-logs/`) through the port rules of the sanitization script (revision 2, as downloaded and
checked in step 1), and recomputes `logs/public/SHA256SUMS` in each commit that has the evidence. The evidence must be rewritten too: the
G16b commit published it before the ports were replaced, and the history would otherwise keep publishing them. The checks: outside
`logs/public` exactly one line of each of the two documents differs between the old and the new tree; inside `logs/public` every change
replaces lines without adding or removing any; the commit subjects are unchanged and in order; every date is still in UTC. The backup
references and the old objects are then removed.

## 6. Re-create the sanitized evidence in logs/public with the port rules

```bash
cp "$DOWNLOAD_DIR/sanitize_evidence.sh" scripts/sanitize_evidence.sh
chmod 755 scripts/sanitize_evidence.sh
rm -rf logs/public/reviews logs/public/review-logs
mkdir -p logs/public/reviews logs/public/review-logs
for f in logs/review/*.md; do scripts/sanitize_evidence.sh --ports "$PORTS" < "$f" > "logs/public/reviews/$(basename "$f")"; done
for f in logs/review/G0[0-7]*.review.log; do scripts/sanitize_evidence.sh --pre-utc --ports "$PORTS" < "$f" > "logs/public/review-logs/$(basename "$f")"; done
for f in logs/review/G0[89]*.review.log logs/review/G1*.review.log; do scripts/sanitize_evidence.sh --ports "$PORTS" < "$f" > "logs/public/review-logs/$(basename "$f")"; done
(cd logs/review && sha256sum *.md *.review.log) > logs/public/ORIGINALS.sha256
awk 'NR == FNR {orig[FNR] = $1; n = FNR; next} {print (FNR <= n ? orig[FNR] : "-"), $1}' "$PROJECT_ROOT/build/g16b-commits-before.txt" "$PROJECT_ROOT/build/g16c-commits-before.txt" > "$PROJECT_ROOT/build/g16c-map-left.txt"
{ echo "# reviewed-hash after-G16b published-hash subject"; paste -d' ' "$PROJECT_ROOT/build/g16c-map-left.txt" <(cut -d' ' -f1 "$PROJECT_ROOT/build/g16c-commits-after.txt") <(cut -d' ' -f2- "$PROJECT_ROOT/build/g16c-commits-after.txt"); } > logs/public/COMMIT_MAP.txt
(cd logs/public && find reviews review-logs -type f | sort | xargs sha256sum) > logs/public/SHA256SUMS
ls logs/public/reviews | wc -l
ls logs/public/review-logs | wc -l
for f in logs/public/reviews/* logs/public/review-logs/*; do echo "$(diff "logs/review/$(basename "$f")" "$f" | grep -c '^>') $f"; done | awk '$1 > 0'
cat logs/public/COMMIT_MAP.txt
```

Revision 2 of the sanitization script replaces revision 1 in `scripts/`. All public copies are made again from `logs/review/`, now
also with the port rules (`--ports`), and including this round's new material: the G16b review log, `G16b_review.md`, and `CHECKPOINT_4.md`.
`COMMIT_MAP.txt` gets three hash columns: the hash cited in the reviews (G00-G16a), the hash after G16b (cited in the G16b review), and the
hash that will be published.

## 7. Commit the updated publication material (local only, UTC)

```bash
git add scripts/sanitize_evidence.sh logs/public
git status --short
TZ=UTC0 git commit -q -m "G16c: listening ports replaced in the published material"
git log -1 --format='%h  %aI  %an <%ae>  %s'
```

One commit with the updated script and evidence. The G16c script and document stay untracked; G17 commits them.

## 8. Audit everything that will be pushed, in the whole history

```bash
LOCAL_OFFSET="$(env -u TZ date +%:z)"
LOCAL_OFFSET_COMPACT="$(env -u TZ date +%z)"
LOCAL_ZONE="$(env -u TZ date +%Z)"
LOCAL_TZNAME="$(timedatectl show -p Timezone --value)"
test -n "$LOCAL_OFFSET" -a -n "$LOCAL_OFFSET_COMPACT" -a -n "$LOCAL_ZONE" -a -n "$LOCAL_TZNAME"
git grep -l -I -w -F -f "$PROJECT_ROOT/build/private/listening-ports-high.txt" $(git rev-list --all) || echo "(listening ports from 1024: not found)"
git grep -n -I -E 'Listening TCP ports: [0-9]|already in use: [0-9]|listens on [0-9]+ \(G00\)|for example [0-9]+, G00' $(git rev-list --all) || echo "(sentences naming a listening port: not found)"
awk '/^\$ ss -ltnH$/ {f = 1; next} f && /^\$ / {next} f && /^[0-9]+$/ {print FILENAME ": " FNR; next} {f = 0}' logs/public/review-logs/* || true
test -z "$(git grep -l -I -w -F -f "$PROJECT_ROOT/build/private/listening-ports-high.txt" $(git rev-list --all))"
test -z "$(git grep -l -I -E 'Listening TCP ports: [0-9]|already in use: [0-9]|listens on [0-9]+ \(G00\)|for example [0-9]+, G00' $(git rev-list --all))"
test -z "$(awk '/^\$ ss -ltnH$/ {f = 1; next} f && /^\$ / {next} f && /^[0-9]+$/ {print FILENAME; next} {f = 0}' logs/public/review-logs/*)"
test -z "$(git grep -l -I -w -F -e "$(id -un)" -e "$(hostname)" $(git rev-list --all))"
test -z "$(git grep -l -I -F -e "$HOME" $(git rev-list --all))"
test -z "$(git grep -l -I -E '/home/[A-Za-z0-9_]' $(git rev-list --all))"
test -z "$(git grep -l -I -F -e "$LOCAL_OFFSET" -e "$LOCAL_OFFSET_COMPACT" -e "$LOCAL_TZNAME" $(git rev-list --all))"
test -z "$(git grep -l -I -w -F -e "$LOCAL_ZONE" $(git rev-list --all))"
test -z "$(git grep -l -I -E 'Requested-By: [^<[]|(Start|End)-Date: [0-9]' $(git rev-list --all))"
test -z "$(git grep -l -I -E 'BEGIN [A-Z ]*PRIVATE KEY|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}' $(git rev-list --all))"
test "$(git log --format='%aI%n%cI' | grep -c -v '+00:00$')" -eq 0
(cd logs/public && sha256sum -c --quiet SHA256SUMS)
git log --format='%ae%n%ce' | sort | uniq -c
```

First the new checks for the ports: no listening port from 1024 upward anywhere in the history (as a whole word); no sentence that
names a listening port; no number-only line after an `ss -ltnH` pipeline in the published logs. Then all checks of G16b again, as strict
`test` lines only, and the check that `SHA256SUMS` matches the published evidence. Each `test` line fails, and is recorded as failed, if
anything is found. The apt pattern does not accept `[` after the field name and its colon, so that it does not match the committed gate scripts
that contain the pattern itself.

## 9. Record the manifest of what will be pushed

```bash
git ls-files | wc -l
git ls-files -z | xargs -0 du -ch | tail -n 1
git ls-files -z | xargs -0 sha256sum
```

The SHA-256 of every file that will be pushed; G17 compares against this list.

## 10. Check the project

```bash
git status --short
git log --oneline | wc -l
git log --reverse --format='%h  %aI  %s'
```

Expected: only the G16c script and document untracked; 21 commits, all dated in UTC.

## 11. Run all steps with logging

```bash
bash scripts/G16c_port_masking.sh
```

On the first run, use the downloaded copy: `bash ~/download/G16c_port_masking.sh`.
The script stops after steps 1 to 7 if a check failed. If it stops in step 5, restore the history from the bundle of step 4
(`git fetch --update-head-ok <bundle> '+refs/heads/*:refs/heads/*'`, then `git reset --hard main`) before running it again.
