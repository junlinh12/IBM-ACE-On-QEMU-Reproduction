# G16b: Prepare the Publication

G16a found what must change before anything is published (see `logs/review/G16a_review.md`). This gate makes those changes, adds the
license and the README chosen by the owner, creates the sanitized evidence, and audits the whole history again. It changes the local
repository only; nothing is pushed. The policy is described in [`docs/PUBLICATION.md`](PUBLICATION.md).

Previous gate: **G16a PASS** (audit).

The same commands are run, with logging, by [`scripts/G16b_publication_prep.sh`](../scripts/G16b_publication_prep.sh).

**No local time-zone value is written into this gate's files.** The local UTC offset, its compact form, the zone abbreviation, and the zone
name are read at run time (`env -u TZ date`, `timedatectl`), like the user name and the host name in G16a.

**This gate rewrites the Git history once.** All commit hashes change. Before the rewrite, the complete history is saved to a private Git
bundle in `logs/`, and `logs/public/COMMIT_MAP.txt` maps the hashes cited in the reviews to the new ones. The rewrite is safe only because
nothing has been pushed yet.

Set the paths first:

```bash
PROJECT_ROOT=~/projects/IBM-ACE-On-QEMU-Reproduction
DOWNLOAD_DIR=~/download
```

## 1. Verify the downloaded files and all sealed evidence

```bash
cd "$DOWNLOAD_DIR"
sha256sum G16b_publication_prep.sh G16b_publication_prep.md
echo "2b71a7502777785bb1af4952c0cd3785cda8484621a511b6992bd8ff9d109f1b  G16a_review.md" | sha256sum -c -
echo "51b7bd444daa95decdd7104ad0a21d36bc31a37aef48cb788e2a855e1127968c  README.md" | sha256sum -c -
echo "4471545534053cbb255144d75fc76683695ba390c33d048f12c93216a185aa13  NOTICE" | sha256sum -c -
echo "a590b98e43d18de93f4ef71792d78126d5c10eadc131dacde12841ae38ac7533  PUBLICATION.md" | sha256sum -c -
echo "f09150d7c7bbbf8f868587c44b489376a343b28358be16647f0e9902b0a6b958  sanitize_evidence.sh" | sha256sum -c -
cd "$PROJECT_ROOT/logs"
sha256sum -c *.sha256
```

Expected: every line ends with `OK`. If any check fails, stop.

## 2. Commit the reviewed G16a work, with copies that read the local offset at run time

```bash
cd "$PROJECT_ROOT"
cp "$DOWNLOAD_DIR/G16a_review.md" logs/review/
export LOCAL_OFFSET="$(env -u TZ date +%:z)"
perl -pi -e 's/\x27\Q$ENV{LOCAL_OFFSET}\E\x27/"\$(env -u TZ date +%:z)"/g; s/\(\Q$ENV{LOCAL_OFFSET}\E: not found\)/(local offset: not found)/g; s/\(no \Q$ENV{LOCAL_OFFSET}\E in logs\/review\)/(no local offset in logs\/review)/g; s/`\Q$ENV{LOCAL_OFFSET}\E`/a non-UTC offset/g' scripts/G16a_publication_audit.sh docs/G16a_publication_audit.md
test -z "$(grep -F -e "$LOCAL_OFFSET" scripts/G16a_publication_audit.sh docs/G16a_publication_audit.md)"
sha256sum logs/G16a_*.input.sh scripts/G16a_publication_audit.sh
git add scripts/G16a_publication_audit.sh docs/G16a_publication_audit.md
git status --short
git diff --cached --quiet || TZ=UTC0 git commit -m "G16a: publication audit (read-only)"
git log -1 --format='%h  %aI  %an <%ae>  %s'
cp "$DOWNLOAD_DIR/G16b_publication_prep.sh" scripts/
cp "$DOWNLOAD_DIR/G16b_publication_prep.md" docs/
```

The G16a script and document, as run, searched for the local offset as a literal string (G16a review F6). Before they are committed,
`perl` replaces that literal with `"$(env -u TZ date +%:z)"`, which reads the offset at run time, and the prose mention with "a non-UTC
offset". The offset is read with `env -u TZ`, because the logging harness sets `TZ=UTC0`. The `test` line fails unless no copy contains
the offset any more; `sha256sum` shows that the committed script differs from the executed one, which stays sealed in `logs/`.

## 3. Back up the history and record the commits before the rewrite

```bash
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BUNDLE="$PROJECT_ROOT/logs/G16b_pre_rewrite_$STAMP.bundle"
git bundle create "$BUNDLE" --all
git bundle verify "$BUNDLE"
chmod 400 "$BUNDLE"
sha256sum "$BUNDLE"
git log --reverse --format='%h %s' > "$PROJECT_ROOT/build/g16b-commits-before.txt"
wc -l < "$PROJECT_ROOT/build/g16b-commits-before.txt"
```

The bundle holds the complete history before the rewrite. It stays private in `logs/` and is sealed through this gate's log; with it
the owner can always connect the commit hashes cited in the reviews to their content.

## 4. Rewrite the history: dates in UTC, the local offset removed from one document

```bash
OLD_HEAD="$(git rev-parse HEAD)"
FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch -f --env-filter 'GIT_AUTHOR_DATE="${GIT_AUTHOR_DATE% *} +0000"; GIT_COMMITTER_DATE="${GIT_COMMITTER_DATE% *} +0000"; export GIT_AUTHOR_DATE GIT_COMMITTER_DATE' --tree-filter 'if [ -f docs/G03_apt_packages.md ]; then perl -pi -e "s/\`?\Q\$ENV{LOCAL_OFFSET}\E\`?/a non-UTC offset/g" docs/G03_apt_packages.md; fi' -- --all
git diff --numstat "$OLD_HEAD" HEAD
test "$(git diff --numstat "$OLD_HEAD" HEAD)" = "$(printf '1\t1\tdocs/G03_apt_packages.md')"
git update-ref -d refs/original/refs/heads/main
git reflog expire --expire=now --all
git gc --prune=now --quiet
git for-each-ref
git log --reverse --format='%h %s' > "$PROJECT_ROOT/build/g16b-commits-after.txt"
test "$(cut -d' ' -f2- "$PROJECT_ROOT/build/g16b-commits-before.txt" | sha256sum)" = "$(cut -d' ' -f2- "$PROJECT_ROOT/build/g16b-commits-after.txt" | sha256sum)"
test "$(git log --format='%aI%n%cI' | grep -c -v '+00:00$')" -eq 0
git log --reverse --format='%h  %aI  %s' | sed -n '1,3p'
git status --short
```

`git filter-branch` rewrites every commit. The environment filter keeps each date's instant (`@<seconds>`) and sets its offset to
`+0000`; the tree filter replaces the sentence in `docs/G03_apt_packages.md` that names the offset, in every commit where the file exists.
The checks: the new and old trees differ by exactly one changed line in that one file; the commit subjects are the same, in the same order;
no date has another offset than UTC. The backup references and the old objects are then removed, so the old history exists only in the
bundle. Nothing has been pushed, so no published history changes.

## 5. Add the license, the notice, the README, and the publication documents

```bash
cp upstream/ACE-RISCV/LICENSE LICENSE
cmp upstream/ACE-RISCV/LICENSE LICENSE
cp "$DOWNLOAD_DIR/README.md" README.md
cp "$DOWNLOAD_DIR/NOTICE" NOTICE
cp "$DOWNLOAD_DIR/PUBLICATION.md" docs/PUBLICATION.md
cp "$DOWNLOAD_DIR/sanitize_evidence.sh" scripts/sanitize_evidence.sh
chmod 755 scripts/sanitize_evidence.sh
ls -l LICENSE NOTICE README.md docs/PUBLICATION.md scripts/sanitize_evidence.sh
```

`LICENSE` is the upstream file itself (Apache License 2.0); `cmp` confirms it is byte-identical. `README.md`, `NOTICE`,
`docs/PUBLICATION.md`, and `scripts/sanitize_evidence.sh` were reviewed with G16a.

## 6. Create the sanitized evidence in logs/public

```bash
mkdir -p logs/public/reviews logs/public/review-logs
for f in logs/review/*.md; do scripts/sanitize_evidence.sh < "$f" > "logs/public/reviews/$(basename "$f")"; done
for f in logs/review/G0[0-7]*.review.log; do scripts/sanitize_evidence.sh --pre-utc < "$f" > "logs/public/review-logs/$(basename "$f")"; done
for f in logs/review/G0[89]*.review.log logs/review/G1*.review.log; do scripts/sanitize_evidence.sh < "$f" > "logs/public/review-logs/$(basename "$f")"; done
(cd logs/review && sha256sum *.md *.review.log) > logs/public/ORIGINALS.sha256
{ echo "# reviewed-hash published-hash subject"; paste -d' ' <(cut -d' ' -f1 "$PROJECT_ROOT/build/g16b-commits-before.txt") <(cut -d' ' -f1 "$PROJECT_ROOT/build/g16b-commits-after.txt") <(cut -d' ' -f2- "$PROJECT_ROOT/build/g16b-commits-after.txt"); } > logs/public/COMMIT_MAP.txt
(cd logs/public && find reviews review-logs -type f | sort | xargs sha256sum) > logs/public/SHA256SUMS
ls logs/public/reviews | wc -l
ls logs/public/review-logs | wc -l
for f in logs/public/reviews/* logs/public/review-logs/*; do echo "$(diff "logs/review/$(basename "$f")" "$f" | grep -c '^>') $f"; done | awk '$1 > 0'
cat logs/public/COMMIT_MAP.txt
git check-ignore -v logs/public/reviews/G00_review.md logs/public/SHA256SUMS || echo "(logs/public is not ignored)"
```

Every gate review and checkpoint, and every review log, is sanitized into `logs/public/` (docs/PUBLICATION.md). The logs of G00-G07 also
get `--pre-utc`, because they were written before the harness printed UTC. `ORIGINALS.sha256` records the hashes of the private review
copies, `SHA256SUMS` those of the published copies, and `COMMIT_MAP.txt` the commit hashes cited in the reviews next to the published ones.
The loop lists, for each published file, how many lines the sanitization changed. `git check-ignore` confirms that `logs/public` is not
ignored.

## 7. Commit the publication material (local only, UTC)

```bash
git add README.md LICENSE NOTICE docs/PUBLICATION.md scripts/sanitize_evidence.sh logs/public
git status --short | grep -v '^A ' || echo "(only added files)"
git diff --cached --stat | tail -n 1
TZ=UTC0 git commit -q -m "G16b: license, notice, README, and sanitized evidence for publication"
git log -1 --format='%h  %aI  %an <%ae>  %s'
```

One commit with the publication material. The G16b script and document stay untracked; G17 commits them with this gate's sanitized
review log.

## 8. Audit everything that will be pushed, in the whole history

```bash
LOCAL_OFFSET_COMPACT="$(env -u TZ date +%z)"
LOCAL_ZONE="$(env -u TZ date +%Z)"
LOCAL_TZNAME="$(timedatectl show -p Timezone --value)"
test -n "$LOCAL_OFFSET" -a -n "$LOCAL_OFFSET_COMPACT" -a -n "$LOCAL_ZONE" -a -n "$LOCAL_TZNAME"
git grep -l -I -w -F -e "$(id -un)" -e "$(hostname)" $(git rev-list --all) || echo "(user name, host name: not found)"
git grep -l -I -F -e "$HOME" $(git rev-list --all) || echo "(home path: not found)"
git grep -l -I -E '/home/[A-Za-z0-9_]' $(git rev-list --all) || echo "(a path under /home: not found)"
git grep -l -I -F -e "$LOCAL_OFFSET" -e "$LOCAL_OFFSET_COMPACT" -e "$LOCAL_TZNAME" $(git rev-list --all) || echo "(local offset, zone name: not found)"
git grep -l -I -w -F -e "$LOCAL_ZONE" $(git rev-list --all) || echo "(zone abbreviation: not found)"
git grep -n -I -E 'Requested-By: [^<]|(Start|End)-Date: [0-9]' $(git rev-list --all) || echo "(apt history details: not found)"
git grep -l -I -E 'BEGIN [A-Z ]*PRIVATE KEY|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}' $(git rev-list --all) || echo "(keys, tokens: not found)"
test -z "$(git grep -l -I -w -F -e "$(id -un)" -e "$(hostname)" $(git rev-list --all))"
test -z "$(git grep -l -I -F -e "$HOME" $(git rev-list --all))"
test -z "$(git grep -l -I -E '/home/[A-Za-z0-9_]' $(git rev-list --all))"
test -z "$(git grep -l -I -F -e "$LOCAL_OFFSET" -e "$LOCAL_OFFSET_COMPACT" -e "$LOCAL_TZNAME" $(git rev-list --all))"
test -z "$(git grep -l -I -w -F -e "$LOCAL_ZONE" $(git rev-list --all))"
test -z "$(git grep -l -I -E 'Requested-By: [^<]|(Start|End)-Date: [0-9]' $(git rev-list --all))"
test -z "$(git grep -l -I -E 'BEGIN [A-Z ]*PRIVATE KEY|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}' $(git rev-list --all))"
test "$(git log --format='%aI%n%cI' | grep -c -v '+00:00$')" -eq 0
git log --format='%ae%n%ce' | sort | uniq -c
git grep -h -I -o -E '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' HEAD | sort | uniq -c
```

The same searches as G16a, over every commit, now including the new commit with the sanitized evidence: the user name, the host name,
the home path and any path under `/home`, the local offset in both forms, the zone name and abbreviation (all read at run time), apt history details, and
private keys or tokens. The first block prints what is found; the `test` lines then fail, and are recorded as failed, if anything is found
or if any commit date is not in UTC. The `test -n` line guards against an empty pattern, which would match everything. The last two lines
list the e-mail addresses of the commits and every IPv4 address in the published tree for the review.

## 9. Record the manifest of what will be pushed

```bash
git ls-files | wc -l
git ls-files -z | xargs -0 du -ch | tail -n 1
git ls-files -z | xargs -0 sha256sum
```

The SHA-256 of every file that will be pushed. G17 compares against this list.

## 10. Check the project

```bash
git status --short
git log --oneline | wc -l
git log --reverse --format='%h  %aI  %s'
```

Expected: only the G16b script and document untracked; 19 commits, all dated in UTC.

## 11. Run all steps with logging

```bash
bash scripts/G16b_publication_prep.sh
```

On the first run, use the downloaded copy: `bash ~/download/G16b_publication_prep.sh`.
The script stops after steps 1 to 7 if a check failed. Step 4 changes the history; if the script stops there, restore the history from the
bundle of step 3 (`git fetch --update-head-ok <bundle> '+refs/heads/*:refs/heads/*'`, then `git reset --hard main`) before running it again.
