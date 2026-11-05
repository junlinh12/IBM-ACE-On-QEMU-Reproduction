#!/usr/bin/env bash
# =============================================================================
#  IBM-ACE-On-QEMU-Reproduction
#  G16b : Prepare the publication: history in UTC, license, README, sanitized evidence, audit
#
#  Steps 1-10 below are plain Linux commands, identical to docs/G16b_publication_prep.md.
#  Backs up the history to a private bundle, rewrites every commit date to UTC (same instants)
#  and one sentence of docs/G03_apt_packages.md, adds LICENSE, NOTICE, README.md, docs/PUBLICATION.md
#  and scripts/sanitize_evidence.sh, creates the sanitized evidence in logs/public, commits, and
#  audits the whole history again. Local time-zone values are read at run time only.
#  No sudo. Nothing is pushed.
#
#  Before running, put these seven files in ~/download:
#    G16b_publication_prep.sh   G16b_publication_prep.md   G16a_review.md
#    README.md   NOTICE   PUBLICATION.md   sanitize_evidence.sh
#
#  Usage :  bash ~/download/G16b_publication_prep.sh        (do not use sudo)
#  Upload:  logs/review/G16b_*.review.log   (masked copy)
# =============================================================================

# ---------------- Logging harness: start (not part of the procedure) --------
set -u -o pipefail
umask 077                                   # evidence is readable by owner only
export LC_ALL=C                             # English, stable command output
export TZ=UTC0                              # every printed time in UTC (SAFETY_AUDIT A17)

if [ "$(id -u)" -eq 0 ]; then echo "Do not run as root or with sudo." >&2; exit 2; fi

PROJECT_ROOT="$HOME/projects/IBM-ACE-On-QEMU-Reproduction"
DOWNLOAD_DIR="$HOME/download"
LOG_DIR="$PROJECT_ROOT/logs"
if [ ! -d "$LOG_DIR/review" ] || [ ! -d "$PROJECT_ROOT/.git" ]; then
    echo "Project not prepared. Run G00 and G01 first." >&2; exit 2
fi
for p in "$PROJECT_ROOT" "$LOG_DIR" "$DOWNLOAD_DIR"; do
    if [ -L "$p" ]; then echo "Symbolic link at $p; check manually." >&2; exit 2; fi
done

RAW="$(mktemp "$LOG_DIR/G16b_$(date -u +%Y%m%dT%H%M%SZ)_XXXXXX.raw.log")" || exit 2
RUN_ID="$(basename "$RAW" .raw.log)"
cp "${BASH_SOURCE[0]}" "$LOG_DIR/$RUN_ID.input.sh" || exit 2

exec 3>&1 4>&2                              # keep the terminal on fd 3/4
exec >>"$RAW" 2>&1                          # everything else goes to the log
PS4='$ '                                    # traced commands look like "$ cmd"
trap '{ rc=$?; set +x; } 2>/dev/null; echo "### FAILED: exit=$rc line=$LINENO"; set -x' ERR

section() {                                 # print a step title to log and terminal
    { set +x; } 2>/dev/null
    printf '\n===== %s =====\n' "$1"
    printf '  %s\n' "$1" >&3
    set -x
}

finish() {                                  # summary, seal, masked copy
    { set +x; } 2>/dev/null
    FINISHED=1
    trap - ERR
    FAILED="$(grep -c '^### FAILED:' "$RAW")"
    printf '\n===== SUMMARY =====\nfailed_commands=%s  %s\n' "$FAILED" "$1"
    exec 1>&3 2>&4
    ( cd "$LOG_DIR" && sha256sum "$RUN_ID.raw.log" "$RUN_ID.input.sh" > "$RUN_ID.sha256" \
      && sha256sum -c --quiet "$RUN_ID.sha256" ) || { echo "Seal failed." >&2; exit 2; }
    chmod 400 "$RAW" "$LOG_DIR/$RUN_ID.input.sh" "$LOG_DIR/$RUN_ID.sha256"
    esc() { printf '%s' "$1" | sed 's/[][\.*^$|/]/\\&/g'; }
    local user_name host_name review mask
    user_name="$(id -un)"
    host_name="$(hostname 2>/dev/null || echo unknown-host)"
    review="$LOG_DIR/review/$RUN_ID.review.log"
    {
        sed -e "s|$(esc "$HOME")|~|g" \
            -e "s|\<$(esc "$user_name")\>|<user>|g" \
            -e "s|\<$(esc "$host_name")\>|<host>|g" "$RAW"
        echo "# masked_from_raw_sha256=$(sha256sum "$RAW" | cut -d' ' -f1)"
    } > "$review"
    chmod 400 "$review"
    if grep -qF "$HOME" "$review" || grep -qwF -e "$user_name" -e "$host_name" "$review"; then
        mask="WARNING - personal strings remain, do not upload"
    else
        mask="OK"
    fi
    echo
    echo "Result          : $1"
    echo "Failed commands : $FAILED"
    echo "Mask check      : $mask"
    echo "Upload          : logs/review/$RUN_ID.review.log"
    echo "Keep local      : logs/$RUN_ID.raw.log"
}

stop_if_failed() {                          # stop the gate if any command failed so far
    { set +x; } 2>/dev/null
    if grep -q '^### FAILED:' "$RAW"; then
        printf '  STOPPED: a required check failed\n' >&3
        finish "STOPPED at: $1"
        exit 1
    fi
    set -x
}

# Seal the log on every exit, also when the shell stops unexpectedly (for example an unset variable).
trap '{ rc=$?; set +x; } 2>/dev/null; [ -n "${FINISHED:-}" ] || finish "ABORTED: shell exited with status $rc"' EXIT

echo "# G16b Publication Prep | run=$RUN_ID | input_sha256=$(sha256sum "$LOG_DIR/$RUN_ID.input.sh" | cut -d' ' -f1)"
echo "# previous gate: G16a PASS (see logs/review/G16a_review.md)"
printf 'G16b Publication Prep (%s)\n' "$RUN_ID" >&3
set -x
# ---------------- Logging harness: end ---------------------------------------


section "1. Verify the downloaded files and all sealed evidence"
cd "$DOWNLOAD_DIR"
sha256sum G16b_publication_prep.sh G16b_publication_prep.md
echo "2b71a7502777785bb1af4952c0cd3785cda8484621a511b6992bd8ff9d109f1b  G16a_review.md" | sha256sum -c -
echo "51b7bd444daa95decdd7104ad0a21d36bc31a37aef48cb788e2a855e1127968c  README.md" | sha256sum -c -
echo "4471545534053cbb255144d75fc76683695ba390c33d048f12c93216a185aa13  NOTICE" | sha256sum -c -
echo "a590b98e43d18de93f4ef71792d78126d5c10eadc131dacde12841ae38ac7533  PUBLICATION.md" | sha256sum -c -
echo "f09150d7c7bbbf8f868587c44b489376a343b28358be16647f0e9902b0a6b958  sanitize_evidence.sh" | sha256sum -c -
cd "$PROJECT_ROOT/logs"
sha256sum -c *.sha256
stop_if_failed "step 1"

section "2. Commit the reviewed G16a work, with copies that read the local offset at run time"
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
stop_if_failed "step 2"

section "3. Back up the history and record the commits before the rewrite"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BUNDLE="$PROJECT_ROOT/logs/G16b_pre_rewrite_$STAMP.bundle"
git bundle create "$BUNDLE" --all
git bundle verify "$BUNDLE"
chmod 400 "$BUNDLE"
sha256sum "$BUNDLE"
git log --reverse --format='%h %s' > "$PROJECT_ROOT/build/g16b-commits-before.txt"
wc -l < "$PROJECT_ROOT/build/g16b-commits-before.txt"
stop_if_failed "step 3"

section "4. Rewrite the history: dates in UTC, the local offset removed from one document"
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
stop_if_failed "step 4"

section "5. Add the license, the notice, the README, and the publication documents"
cp upstream/ACE-RISCV/LICENSE LICENSE
cmp upstream/ACE-RISCV/LICENSE LICENSE
cp "$DOWNLOAD_DIR/README.md" README.md
cp "$DOWNLOAD_DIR/NOTICE" NOTICE
cp "$DOWNLOAD_DIR/PUBLICATION.md" docs/PUBLICATION.md
cp "$DOWNLOAD_DIR/sanitize_evidence.sh" scripts/sanitize_evidence.sh
chmod 755 scripts/sanitize_evidence.sh
ls -l LICENSE NOTICE README.md docs/PUBLICATION.md scripts/sanitize_evidence.sh
stop_if_failed "step 5"

section "6. Create the sanitized evidence in logs/public"
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
stop_if_failed "step 6"

section "7. Commit the publication material (local only, UTC)"
git add README.md LICENSE NOTICE docs/PUBLICATION.md scripts/sanitize_evidence.sh logs/public
git status --short | grep -v '^A ' || echo "(only added files)"
git diff --cached --stat | tail -n 1
TZ=UTC0 git commit -q -m "G16b: license, notice, README, and sanitized evidence for publication"
git log -1 --format='%h  %aI  %an <%ae>  %s'
stop_if_failed "step 7"

section "8. Audit everything that will be pushed, in the whole history"
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

section "9. Record the manifest of what will be pushed"
git ls-files | wc -l
git ls-files -z | xargs -0 du -ch | tail -n 1
git ls-files -z | xargs -0 sha256sum

section "10. Check the project"
git status --short
git log --oneline | wc -l
git log --reverse --format='%h  %aI  %s'


# ---------------- Logging harness: finish (not part of the procedure) -------
finish "completed"
