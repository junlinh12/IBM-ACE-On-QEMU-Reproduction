#!/usr/bin/env bash
# =============================================================================
#  IBM-ACE-On-QEMU-Reproduction
#  G01 : Project skeleton, charter, Git ignore rules, local Git identity
#
#  Steps 1-7 below are plain Linux commands, identical to docs/G01_project_skeleton.md.
#  Writes only inside the project folder. Nothing is cloned, built, committed or pushed.
#
#  Before running, put these six files in ~/download:
#    G01_project_skeleton.sh   G01_project_skeleton.md   PROJECT_CHARTER.md
#    G00_host_baseline.sh      G00_host_baseline.md      G00_review.md
#
#  Usage :  bash ~/download/G01_project_skeleton.sh        (do not use sudo)
#  Upload:  logs/review/G01_*.review.log   (masked copy)
# =============================================================================

# ---------------- Logging harness: start (not part of the procedure) --------
set -u -o pipefail
umask 077                                   # evidence is readable by owner only
export LC_ALL=C                             # English, stable command output

if [ "$(id -u)" -eq 0 ]; then echo "Do not run as root or with sudo." >&2; exit 2; fi

PROJECT_ROOT="$HOME/projects/IBM-ACE-On-QEMU-Reproduction"
DOWNLOAD_DIR="$HOME/download"
LOG_DIR="$PROJECT_ROOT/logs"
OLD_LOG_DIR="$PROJECT_ROOT/Project Logs"

# One-time migration on the reference host: the first G00 run used "Project Logs/".
# The folder is renamed as a whole; file contents are re-checked in step 1.
MIGRATION="none"
if [ -d "$OLD_LOG_DIR" ] && [ -e "$LOG_DIR" ]; then
    echo "Both 'Project Logs' and 'logs' exist; check manually." >&2; exit 2
fi
if [ -d "$OLD_LOG_DIR" ]; then
    mv "$OLD_LOG_DIR" "$LOG_DIR" || { echo "Cannot rename 'Project Logs' to 'logs'." >&2; exit 2; }
    MIGRATION="renamed 'Project Logs/' to 'logs/'"
fi

if [ ! -d "$LOG_DIR/review" ]; then echo "logs/ not found. Run G00 first." >&2; exit 2; fi
for p in "$PROJECT_ROOT" "$LOG_DIR" "$DOWNLOAD_DIR"; do
    if [ -L "$p" ]; then echo "Symbolic link at $p; check manually." >&2; exit 2; fi
done

RAW="$(mktemp "$LOG_DIR/G01_$(date -u +%Y%m%dT%H%M%SZ)_XXXXXX.raw.log")" || exit 2
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

echo "# G01 Project Skeleton | run=$RUN_ID | input_sha256=$(sha256sum "$LOG_DIR/$RUN_ID.input.sh" | cut -d' ' -f1)"
echo "# previous gate: G00 PASS (see logs/review/G00_review.md)"
echo "# log folder migration: $MIGRATION"
printf 'G01 Project Skeleton (%s)\n' "$RUN_ID" >&3
printf '  log folder migration: %s\n' "$MIGRATION" >&3
set -x
# ---------------- Logging harness: end ---------------------------------------


section "1. Verify the downloaded files and the G00 evidence"
cd "$DOWNLOAD_DIR"
sha256sum G01_project_skeleton.sh G01_project_skeleton.md
echo "d88c31af440a9a8d820a46e3df4855c130a004db19602c00e5ec2aeb38e48fb4  G00_host_baseline.sh" | sha256sum -c -
echo "c542d734b4eabd0a4f94a8284f7f8522138f32512f0c6668a85f471321f98666  G00_host_baseline.md" | sha256sum -c -
echo "574fa11c5dd1c9d340634ed86aa6ca6d3b72c9d1b5d37476653ce8e7e305577e  G00_review.md" | sha256sum -c -
echo "75fa04fadf3bcb70f0575d2c06abb073e3059824346f03599a575a0b5aebde1e  PROJECT_CHARTER.md" | sha256sum -c -
cd "$PROJECT_ROOT/logs"
sha256sum -c G00_*.sha256
stop_if_failed "step 1"

section "2. Create the project layout"
cd "$PROJECT_ROOT"
mkdir -p scripts docs patches upstream build logs/public
touch logs/public/.keep

section "3. Install the charter, scripts, documents, and the G00 review"
cp "$DOWNLOAD_DIR/PROJECT_CHARTER.md" PROJECT_CHARTER.md
cp "$DOWNLOAD_DIR/G00_host_baseline.sh" scripts/
cp "$DOWNLOAD_DIR/G01_project_skeleton.sh" scripts/
cp "$DOWNLOAD_DIR/G00_host_baseline.md" docs/
cp "$DOWNLOAD_DIR/G01_project_skeleton.md" docs/
cp "$DOWNLOAD_DIR/G00_review.md" logs/review/
stop_if_failed "step 3"

section "4. Write the Git ignore rules"
cat > .gitignore <<'EOF'
# IBM upstream sources and build artifacts: never published
/upstream/
/build/

# logs: private by default
/logs/**

# Only material approved in G16 is published
!/logs/public/
!/logs/public/**

# Editor and OS files
*.swp
*~
.DS_Store
EOF
cat .gitignore

section "5. Create the local Git repository and identity"
git init -b main
GITHUB_USER=junlinh12
GITHUB_ID=$(curl -fsS "https://api.github.com/users/$GITHUB_USER" | python3 -c 'import json, sys; print(json.load(sys.stdin)["id"])')
stop_if_failed "step 5"
git config user.name "$GITHUB_USER"
git config user.email "$GITHUB_ID+$GITHUB_USER@users.noreply.github.com"
git config --local --list

section "6. Check what Git would publish"
git check-ignore -v upstream/ build/ logs/review/G00_review.md logs/G00_*.raw.log
git add --dry-run --all
git status --short

section "7. Record the project layout"
find . -path ./.git -prune -o -print | sort


# ---------------- Logging harness: finish (not part of the procedure) -------
finish "completed"
