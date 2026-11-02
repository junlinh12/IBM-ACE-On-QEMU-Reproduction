#!/usr/bin/env bash
# =============================================================================
#  IBM-ACE-On-QEMU-Reproduction
#  G05 : Read-only audit of the upstream Makefiles, run scripts, and build configuration
#
#  Steps 1-9 below are plain Linux commands, identical to docs/G05_audit_build_scripts.md.
#  Records, with line numbers, every Makefile and run script of the pinned upstream commit,
#  so that side effects (deletions, process kills, network exposure, source modification,
#  parallelism, external downloads) can be reviewed before anything is built or run.
#  Read-only: nothing is built, run, patched, installed, or pushed. No sudo.
#  One local commit is made for the reviewed G04 work and charter v1.3.
#
#  Before running, put these five files in ~/download:
#    G05_audit_build_scripts.sh   G05_audit_build_scripts.md
#    G04_review.md   CHECKPOINT_1.md   PROJECT_CHARTER.md
#
#  Usage :  bash ~/download/G05_audit_build_scripts.sh        (do not use sudo)
#  Upload:  logs/review/G05_*.review.log   (masked copy)
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

RAW="$(mktemp "$LOG_DIR/G05_$(date -u +%Y%m%dT%H%M%SZ)_XXXXXX.raw.log")" || exit 2
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

echo "# G05 Audit Build Scripts | run=$RUN_ID | input_sha256=$(sha256sum "$LOG_DIR/$RUN_ID.input.sh" | cut -d' ' -f1)"
echo "# previous gate: G04 PASS (see logs/review/G04_review.md); checkpoint 1 recorded"
printf 'G05 Audit Build Scripts (%s)\n' "$RUN_ID" >&3
set -x
# ---------------- Logging harness: end ---------------------------------------


section "1. Verify the downloaded files and all sealed evidence"
cd "$DOWNLOAD_DIR"
sha256sum G05_audit_build_scripts.sh G05_audit_build_scripts.md
echo "16da5430a362ffa750fba019786c44d8bd5a286d99eb5169c891f254fea264f0  G04_review.md" | sha256sum -c -
echo "6d0e9db7e6f48ab2956a70086ddef5fb552c9c5cd69d0b7f303c6a85bdc7d42d  CHECKPOINT_1.md" | sha256sum -c -
echo "8bcf3e3afb1c34524803e47ef9015c64e52139cb9e6ec70efa69185cf13da045  PROJECT_CHARTER.md" | sha256sum -c -
cd "$PROJECT_ROOT/logs"
sha256sum -c *.sha256
stop_if_failed "step 1"

section "2. Commit the reviewed G04 work and charter v1.3 (local only, UTC)"
cd "$PROJECT_ROOT"
cp "$DOWNLOAD_DIR/G04_review.md" logs/review/
cp "$DOWNLOAD_DIR/CHECKPOINT_1.md" logs/review/
cp "$DOWNLOAD_DIR/PROJECT_CHARTER.md" PROJECT_CHARTER.md
git add PROJECT_CHARTER.md scripts/G04_rust_toolchain.sh docs/G04_rust_toolchain.md
git status --short
git diff --cached --quiet || TZ=UTC0 git commit -m "G04: install Rust nightly-2026-03-23; checkpoint 1"
git log -1 --format='%h  %aI  %an <%ae>  %s'
git show --stat --format= HEAD
cp "$DOWNLOAD_DIR/G05_audit_build_scripts.sh" scripts/
cp "$DOWNLOAD_DIR/G05_audit_build_scripts.md" docs/
stop_if_failed "step 2"

section "3. Record the host state for this gate"
uname -r
free -h

section "4. Record the upstream file layout"
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
git ls-files -- ':(exclude)security-monitor/src' ':(exclude)verification'

section "5. Record every Makefile with line numbers"
git ls-files -z -- '*Makefile*' '*.mk' ':(exclude)verification' | xargs -0 -r grep -IHn ''

section "6. Record the run scripts and tools with line numbers"
git ls-files -z -- tools ':(exclude)tools/cove_tap_tool/src' | xargs -0 -r grep -IHn ''

section "7. Index the operations that need review"
git grep -nE 'rm -rf|kill|sudo|hostfwd|git apply|patch |\$\(CARGO\)|cargo fmt|nproc|JLEVEL|-j ?[0-9]' -- ':(exclude)verification' ':(exclude)*.rs' ':(exclude)*.md' || echo "(no matches)"
git grep -nE 'https?://|git://' -- ':(exclude)verification' ':(exclude)*.rs' ':(exclude)*.md' ':(exclude)*Makefile*' || echo "(no matches)"

section "8. Check that the build-time Git sources are reachable"
GIT_TERMINAL_PROMPT=0 timeout 30 git ls-remote git://git.kernel.org/pub/scm/utils/dtc/dtc.git HEAD || echo "(git:// unreachable)"
GIT_TERMINAL_PROMPT=0 timeout 30 git ls-remote https://git.kernel.org/pub/scm/utils/dtc/dtc.git HEAD || echo "(https unreachable)"
GIT_TERMINAL_PROMPT=0 timeout 30 git ls-remote https://github.com/wojciechozga/kvmtool.git refs/heads/cove-integration-03072023 || echo "(unreachable)"

section "9. Check that nothing was modified"
git status --short
cd "$PROJECT_ROOT"
git status --short


# ---------------- Logging harness: finish (not part of the procedure) -------
finish "completed"
