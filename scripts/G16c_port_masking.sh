#!/usr/bin/env bash
# =============================================================================
#  IBM-ACE-On-QEMU-Reproduction
#  G16c : Replace the reference host's listening ports in everything published (owner's decision)
#
#  Steps 1-10 below are plain Linux commands, identical to docs/G16c_port_masking.md.
#  Reads the listening ports from the sealed G00 log into a private file (never printed), backs up
#  the history to a private bundle, rewrites the two documents that name a port in every commit,
#  re-creates the sanitized evidence with the port rules of scripts/sanitize_evidence.sh, commits,
#  and audits the whole history again. No port number and no time-zone value is written into this
#  gate's files. No sudo. Nothing is pushed.
#
#  Before running, put these five files in ~/download:
#    G16c_port_masking.sh   G16c_port_masking.md   G16b_review.md   CHECKPOINT_4.md
#    sanitize_evidence.sh (revision 2)
#
#  Usage :  bash ~/download/G16c_port_masking.sh        (do not use sudo)
#  Upload:  logs/review/G16c_*.review.log   (masked copy)
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

RAW="$(mktemp "$LOG_DIR/G16c_$(date -u +%Y%m%dT%H%M%SZ)_XXXXXX.raw.log")" || exit 2
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

echo "# G16c Port Masking | run=$RUN_ID | input_sha256=$(sha256sum "$LOG_DIR/$RUN_ID.input.sh" | cut -d' ' -f1)"
echo "# previous gate: G16b PASS (see logs/review/G16b_review.md); checkpoint 4 recorded"
printf 'G16c Port Masking (%s)\n' "$RUN_ID" >&3
set -x
# ---------------- Logging harness: end ---------------------------------------


section "1. Verify the downloaded files and all sealed evidence"
cd "$DOWNLOAD_DIR"
sha256sum G16c_port_masking.sh G16c_port_masking.md
echo "ec1db4f19d5251c49edc330520dc0a6b07ed33ac7bd7530c829106564b450ac1  G16b_review.md" | sha256sum -c -
echo "e59f9938ab31eb01c9c2cea12a1ce0007b0fa3e4ceabe9c3a075ee0680557461  CHECKPOINT_4.md" | sha256sum -c -
echo "0c9eee3c401f75ec5fcfb3b9cb745fda69c8bf91bd40db73d80713981086815f  sanitize_evidence.sh" | sha256sum -c -
cd "$PROJECT_ROOT/logs"
sha256sum -c *.sha256
stop_if_failed "step 1"

section "2. Commit the reviewed G16b work (local only, UTC)"
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
stop_if_failed "step 2"

section "3. Read the listening ports from the sealed G00 log into a private file"
PORTS="$PROJECT_ROOT/build/private/listening-ports.txt"
mkdir -p "$PROJECT_ROOT/build/private"
awk '/^\$ ss -ltnH$/ {f = 1; next} f && /^\$ / {next} f && /^[0-9]+$/ {print; next} f {exit}' logs/G00_20261030T122505Z_7St35c.raw.log > "$PORTS"
awk '$1 >= 1024' "$PORTS" > "$PROJECT_ROOT/build/private/listening-ports-high.txt"
wc -l < "$PORTS"
wc -l < "$PROJECT_ROOT/build/private/listening-ports-high.txt"
test "$(wc -l < "$PORTS")" -ge 1
git check-ignore -q build/private/listening-ports.txt
stop_if_failed "step 3"

section "4. Back up the history and record the commits before the rewrite"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BUNDLE="$PROJECT_ROOT/logs/G16c_pre_rewrite_$STAMP.bundle"
git bundle create "$BUNDLE" --all
git bundle verify "$BUNDLE"
chmod 400 "$BUNDLE"
sha256sum "$BUNDLE"
git log --reverse --format='%h %s' > "$PROJECT_ROOT/build/g16c-commits-before.txt"
wc -l < "$PROJECT_ROOT/build/g16c-commits-before.txt"
stop_if_failed "step 4"

section "5. Rewrite the history: the port mentions in two documents"
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
stop_if_failed "step 5"

section "6. Re-create the sanitized evidence in logs/public with the port rules"
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
stop_if_failed "step 6"

section "7. Commit the updated publication material (local only, UTC)"
git add scripts/sanitize_evidence.sh logs/public
git status --short
TZ=UTC0 git commit -q -m "G16c: listening ports replaced in the published material"
git log -1 --format='%h  %aI  %an <%ae>  %s'
stop_if_failed "step 7"

section "8. Audit everything that will be pushed, in the whole history"
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
