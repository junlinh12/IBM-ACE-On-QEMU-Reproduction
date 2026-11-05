#!/usr/bin/env bash
# =============================================================================
#  IBM-ACE-On-QEMU-Reproduction
#  G17 : Publish to the private GitHub repository and verify what GitHub received
#
#  Steps 1-10 below are plain Linux commands, identical to docs/G17_publish.md.
#  Commits the reviewed G16c work and this gate's files with sanitized evidence, audits the whole
#  history a last time, checks without logging in that the repository is not public, pushes to the
#  private repository only if it is empty (never with force), verifies the pushed commit, and forgets
#  the token. The token is typed at git's Password prompt; it is held in memory for at most 5 minutes
#  and never written to disk; no global Git setting is changed.
#  No sudo. The repository is NOT made public by this gate; the owner does that on GitHub.
#
#  Before running: create the empty private repository junlinh12/IBM-ACE-On-QEMU-Reproduction and a
#  fine-grained token for it only (Contents: read and write). Put these four files in ~/download:
#    G17_publish.sh   G17_publish.md   G16c_review.md   G16c_port_masking.md (published copy)
#
#  Usage :  bash ~/download/G17_publish.sh        (in a terminal; do not use sudo)
#  Upload:  logs/review/G17_*.review.log   (masked copy)
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

RAW="$(mktemp "$LOG_DIR/G17_$(date -u +%Y%m%dT%H%M%SZ)_XXXXXX.raw.log")" || exit 2
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

echo "# G17 Publish | run=$RUN_ID | input_sha256=$(sha256sum "$LOG_DIR/$RUN_ID.input.sh" | cut -d' ' -f1)"
echo "# previous gate: G16c PASS (see logs/review/G16c_review.md)"
printf 'G17 Publish (%s)\n' "$RUN_ID" >&3
set -x
# ---------------- Logging harness: end ---------------------------------------


section "1. Verify the downloaded files and all sealed evidence"
cd "$DOWNLOAD_DIR"
sha256sum G17_publish.sh G17_publish.md
echo "ed8218c7ab75a03011a852beb77f84a1ed12ff3b4193e8d6988f9eef7cffbd84  G16c_review.md" | sha256sum -c -
echo "dd73e63c886782a4a370dd83808a5593187fd3a9abe78a43459d58d6d38e2591  G16c_port_masking.md" | sha256sum -c -
cd "$PROJECT_ROOT/logs"
sha256sum -c *.sha256
stop_if_failed "step 1"

section "2. Commit the reviewed G16c work and this gate's files, with sanitized evidence"
cd "$PROJECT_ROOT"
cp "$DOWNLOAD_DIR/G16c_review.md" logs/review/
cp "$DOWNLOAD_DIR/G17_publish.sh" scripts/
cp "$DOWNLOAD_DIR/G17_publish.md" docs/
cp "$DOWNLOAD_DIR/G16c_port_masking.md" docs/G16c_port_masking.md
PORTS="$PROJECT_ROOT/build/private/listening-ports.txt"
test -s "$PORTS"
test -z "$(grep -F -e "$(env -u TZ date +%:z)" -e "$(env -u TZ date +%z)" -e "$(timedatectl show -p Timezone --value)" scripts/G16c_port_masking.sh docs/G16c_port_masking.md scripts/G17_publish.sh docs/G17_publish.md)"
test -z "$(grep -w -F -e "$(env -u TZ date +%Z)" -f "$PROJECT_ROOT/build/private/listening-ports-high.txt" scripts/G16c_port_masking.sh docs/G16c_port_masking.md scripts/G17_publish.sh docs/G17_publish.md)"
rm -rf logs/public/reviews logs/public/review-logs
mkdir -p logs/public/reviews logs/public/review-logs
for f in logs/review/*.md; do scripts/sanitize_evidence.sh --ports "$PORTS" < "$f" > "logs/public/reviews/$(basename "$f")"; done
for f in logs/review/G0[0-7]*.review.log; do scripts/sanitize_evidence.sh --pre-utc --ports "$PORTS" < "$f" > "logs/public/review-logs/$(basename "$f")"; done
for f in logs/review/G0[89]*.review.log logs/review/G1*.review.log; do scripts/sanitize_evidence.sh --ports "$PORTS" < "$f" > "logs/public/review-logs/$(basename "$f")"; done
(cd logs/review && sha256sum *.md *.review.log) > logs/public/ORIGINALS.sha256
(cd logs/public && find reviews review-logs -type f | sort | xargs sha256sum) > logs/public/SHA256SUMS
ls logs/public/reviews | wc -l
ls logs/public/review-logs | wc -l
git add scripts/G16c_port_masking.sh docs/G16c_port_masking.md scripts/G17_publish.sh docs/G17_publish.md logs/public
git status --short
TZ=UTC0 git commit -q -m "G16c: gate files and sanitized evidence; G17 gate files"
git log -1 --format='%h  %aI  %an <%ae>  %s'
stop_if_failed "step 2"

section "3. Audit everything that will be pushed, a last time"
LOCAL_OFFSET="$(env -u TZ date +%:z)"
LOCAL_OFFSET_COMPACT="$(env -u TZ date +%z)"
LOCAL_ZONE="$(env -u TZ date +%Z)"
LOCAL_TZNAME="$(timedatectl show -p Timezone --value)"
test -n "$LOCAL_OFFSET" -a -n "$LOCAL_OFFSET_COMPACT" -a -n "$LOCAL_ZONE" -a -n "$LOCAL_TZNAME"
test -z "$(git ls-files | grep -v -E '^(\.gitignore|LICENSE|NOTICE|README\.md|PROJECT_CHARTER\.md|docs/|scripts/|patches/|logs/public/)')"
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
test "$(git log --format='%ae%n%ce' | sort -u)" = "238169016+junlinh12@users.noreply.github.com"
(cd logs/public && sha256sum -c --quiet SHA256SUMS)
git ls-files | wc -l
git ls-files -z | xargs -0 du -b | sort -n | tail -n 3
stop_if_failed "step 3"

section "4. Check without logging in that the repository is not public"
REPO=junlinh12/IBM-ACE-On-QEMU-Reproduction
curl -s -o /dev/null -w '%{http_code}\n' "https://api.github.com/repos/$REPO"
test "$(curl -s -o /dev/null -w '%{http_code}' "https://api.github.com/repos/$REPO")" = 404
stop_if_failed "step 4"

section "5. Set the remote in the local configuration and check the credential settings"
URL="https://junlinh12@github.com/$REPO.git"
git remote get-url origin 2>/dev/null || git remote add origin "$URL"
test "$(git config --get remote.origin.url)" = "$URL"
git config --show-origin --get-all credential.helper || echo "(no credential helper configured)"
env | grep -E '^(GIT_ASKPASS|SSH_ASKPASS|GIT_TERMINAL_PROMPT)=' || echo "(no prompt override in the environment)"
stop_if_failed "step 5"

section "6. Log in once and check that the repository on GitHub is empty"
echo "Type the token at git's Password prompt. It is not shown and not stored on disk." > /dev/tty || true
REMOTE_REFS="$(git -c credential.helper= -c 'credential.helper=cache --timeout=300' ls-remote origin)" && LS_OK=1 || LS_OK=0
echo "login and read: $LS_OK; references on GitHub before the push: $(printf '%s' "$REMOTE_REFS" | grep -c .)"
test "$LS_OK" = 1

section "7. Push only if the repository on GitHub is empty"
if [ "$LS_OK" = 1 ] && [ -z "$REMOTE_REFS" ]; then git -c credential.helper= -c 'credential.helper=cache --timeout=300' push -u origin main; else echo "(nothing was pushed: the repository could not be read or is not empty)"; fi

section "8. Verify what GitHub received"
git -c credential.helper= -c 'credential.helper=cache --timeout=300' ls-remote origin
test "$(git -c credential.helper= -c 'credential.helper=cache --timeout=300' ls-remote --heads origin | wc -l)" -eq 1
test "$(git -c credential.helper= -c 'credential.helper=cache --timeout=300' ls-remote origin refs/heads/main | cut -f1)" = "$(git rev-parse HEAD)"
test "$(git rev-parse origin/main)" = "$(git rev-parse HEAD)"
git status -sb | sed -n '1p'

section "9. Forget the token and check that the repository is still private"
git credential-cache exit || echo "(no credential cache was running)"
test "$(curl -s -o /dev/null -w '%{http_code}' "https://api.github.com/repos/$REPO")" = 404
git config --show-origin --get-all credential.helper || echo "(no credential helper configured)"
git remote -v

section "10. Record the published state"
git rev-parse HEAD
git log --oneline | wc -l
git log -1 --format='%h  %aI  %s'
git status --short


# ---------------- Logging harness: finish (not part of the procedure) -------
finish "completed"
