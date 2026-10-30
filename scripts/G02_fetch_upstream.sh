#!/usr/bin/env bash
# =============================================================================
#  IBM-ACE-On-QEMU-Reproduction
#  G02 : Fetch IBM ACE-RISCV at the pinned commit and record source provenance
#
#  Steps 1-8 below are plain Linux commands, identical to docs/G02_fetch_upstream.md.
#  Downloads the upstream sources into upstream/ (ignored by Git). Nothing is built,
#  installed, or pushed. One local commit is made for the reviewed G00-G01 work.
#
#  Before running, put these three files in ~/download:
#    G02_fetch_upstream.sh   G02_fetch_upstream.md   G01_review.md
#
#  Usage :  bash ~/download/G02_fetch_upstream.sh        (do not use sudo)
#  Upload:  logs/review/G02_*.review.log   (masked copy)
#  Time  :  the submodule download (step 6) can take a long time.
# =============================================================================

# ---------------- Logging harness: start (not part of the procedure) --------
set -u -o pipefail
umask 077                                   # evidence is readable by owner only
export LC_ALL=C                             # English, stable command output

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

RAW="$(mktemp "$LOG_DIR/G02_$(date -u +%Y%m%dT%H%M%SZ)_XXXXXX.raw.log")" || exit 2
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

echo "# G02 Fetch Upstream | run=$RUN_ID | input_sha256=$(sha256sum "$LOG_DIR/$RUN_ID.input.sh" | cut -d' ' -f1)"
echo "# previous gate: G01 PASS (see logs/review/G01_review.md)"
printf 'G02 Fetch Upstream (%s)\n' "$RUN_ID" >&3
set -x
# ---------------- Logging harness: end ---------------------------------------


section "1. Verify the downloaded files and all sealed evidence"
cd "$DOWNLOAD_DIR"
sha256sum G02_fetch_upstream.sh G02_fetch_upstream.md
echo "101ee05e9d1cd8490033a483381a55089a29974653ecbe1641858ef6b5ff79b1  G01_review.md" | sha256sum -c -
cd "$PROJECT_ROOT/logs"
sha256sum -c *.sha256
sha256sum *.input.sh
stop_if_failed "step 1"

section "2. Commit the reviewed G00-G01 work (local only)"
cd "$PROJECT_ROOT"
cp "$DOWNLOAD_DIR/G01_review.md" logs/review/
git add .gitignore PROJECT_CHARTER.md logs/public/.keep scripts/G00_host_baseline.sh scripts/G01_project_skeleton.sh docs/G00_host_baseline.md docs/G01_project_skeleton.md
git status --short
git diff --cached --quiet || git commit -m "G00-G01: host baseline and project skeleton"
git log -1 --format='commit %H%nauthor %an <%ae>%ndate   %aI%n%n    %s'
git show --stat --format= HEAD
cp "$DOWNLOAD_DIR/G02_fetch_upstream.sh" scripts/
cp "$DOWNLOAD_DIR/G02_fetch_upstream.md" docs/
stop_if_failed "step 2"

section "3. Clone the upstream repository"
cd "$PROJECT_ROOT/upstream"
date -u
[ -d ACE-RISCV/.git ] || GIT_TERMINAL_PROMPT=0 git clone https://github.com/IBM/ACE-RISCV.git ACE-RISCV
date -u
stop_if_failed "step 3"

section "4. Check out the pinned commit"
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
git checkout --detach 1ebdebf4cacc04fcb83191053b4e979cbcdcb2d6
git rev-parse HEAD
git log -1 --format='commit  %H%ndate    %cI%nsubject %s'
git rev-parse origin/main
git status --short
stop_if_failed "step 4"

section "5. Record the submodule pins before fetching"
cat .gitmodules
git submodule status

section "6. Fetch the submodules"
date -u
GIT_TERMINAL_PROMPT=0 git -c url."https://github.com/".insteadOf="git@github.com:" submodule update --init --recursive
date -u
git submodule status --recursive
stop_if_failed "step 6"

section "7. Record the build inputs declared by upstream"
cat rust-toolchain.toml
cat .github/workflows/build.yml
git grep -nE 'https?://|git://' -- '*Makefile*' '*.mk'

section "8. Check the result"
git status --short
du -sh "$PROJECT_ROOT/upstream/ACE-RISCV"
df -h "$PROJECT_ROOT"
cd "$PROJECT_ROOT"
git check-ignore -v upstream/ACE-RISCV
git status --short


# ---------------- Logging harness: finish (not part of the procedure) -------
finish "completed"
