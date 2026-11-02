#!/usr/bin/env bash
# =============================================================================
#  IBM-ACE-On-QEMU-Reproduction
#  G07 : Build the ACE tools (make tools): command-line scripts and the TAP tool
#        Revision 2: the TAP tool is built with Rust toolchain 1.98.1 selected by
#        RUSTUP_TOOLCHAIN (the host's stable toolchain has no rustfmt; first run BLOCKED).
#
#  Steps 1-10 below are plain Linux commands, identical to docs/G07_tools.md.
#  Uses the build settings in scripts/build_env.sh (docs/SAFETY_AUDIT.md).
#  Adds the Rust toolchain 1.98.1; the stable and default toolchains are NOT changed.
#  Downloads Rust crates from crates.io into build/cargo-home (not the shared ~/.cargo).
#  No sudo. Nothing is pushed.
#
#  Before running, put these four files in ~/download:
#    G07_tools.sh (revision 2)   G07_tools.md (revision 2)   G06_review.md   G07_run1_review.md
#
#  Usage :  bash ~/download/G07_tools.sh        (do not use sudo)
#  Upload:  logs/review/G07_*.review.log   (masked copy)
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

RAW="$(mktemp "$LOG_DIR/G07_$(date -u +%Y%m%dT%H%M%SZ)_XXXXXX.raw.log")" || exit 2
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

echo "# G07 Tools | run=$RUN_ID | input_sha256=$(sha256sum "$LOG_DIR/$RUN_ID.input.sh" | cut -d' ' -f1)"
echo "# previous gate: G06 PASS; G07 first run BLOCKED (see logs/review/G07_run1_review.md)"
printf 'G07 Tools (%s)\n' "$RUN_ID" >&3
set -x
# ---------------- Logging harness: end ---------------------------------------


section "1. Verify the downloaded files and all sealed evidence"
cd "$DOWNLOAD_DIR"
sha256sum G07_tools.sh G07_tools.md
echo "dfbfc14deddc132b5b93cb1abab9da05f92b9dcf289cdb0a193016db7fff87cc  G06_review.md" | sha256sum -c -
echo "9525f71a312ad4d2e94bc80a5ce55089b9389d57e4f497a842b5bfddcf895b57  G07_run1_review.md" | sha256sum -c -
cd "$PROJECT_ROOT/logs"
sha256sum -c *.sha256
stop_if_failed "step 1"

section "2. Commit the reviewed G06 work (local only, UTC)"
cd "$PROJECT_ROOT"
cp "$DOWNLOAD_DIR/G06_review.md" logs/review/
cp "$DOWNLOAD_DIR/G07_run1_review.md" logs/review/
git add scripts/G06_devtools.sh docs/G06_devtools.md
git status --short
git diff --cached --quiet || TZ=UTC0 git commit -m "G06: RISC-V GNU toolchain (make devtools)"
git log -1 --format='%h  %aI  %an <%ae>  %s'
cp "$DOWNLOAD_DIR/G07_tools.sh" scripts/
cp "$DOWNLOAD_DIR/G07_tools.md" docs/
stop_if_failed "step 2"

section "3. Record the host and source state before the build"
uname -r
free -h
df -h "$PROJECT_ROOT"
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
git status --short

section "4. Set the build environment"
source "$PROJECT_ROOT/scripts/build_env.sh"
env | grep -E '^(ACE_DIR|QEMU_SOURCE_DIR|BR2_DL_DIR|CARGO_HOME|BR2_JLEVEL|OMP_NUM_THREADS|CARGO_BUILD_JOBS)=' | sort
stop_if_failed "step 4"

section "5. Install Rust 1.98.1 for the TAP tool (stable and default unchanged)"
rustup toolchain list
rustup toolchain install 1.98.1 --profile minimal --component rustfmt --no-self-update
rustup toolchain list
rustup default
stop_if_failed "step 5"

section "6. Select Rust 1.98.1 for the TAP tool and check it equals the host's stable"
cd "$PROJECT_ROOT/upstream/ACE-RISCV/tools/cove_tap_tool"
cat rust-toolchain.toml; echo
rustup run stable rustc --version
export RUSTUP_TOOLCHAIN=1.98.1
rustup show active-toolchain
rustc --version
cargo --version
cargo fmt --version
test "$(rustup run stable rustc --version)" = "$(rustc --version)"
stop_if_failed "step 6"

section "7. Build the tools with the upstream Makefile"
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
date -u
make -j2 tools
date -u
unset RUSTUP_TOOLCHAIN
stop_if_failed "step 7"

section "8. Verify the installed tools"
ls -l "$ACE_DIR/tools"
sha256sum "$ACE_DIR/tools/cove-tap-tool"
"$ACE_DIR/tools/cove-tap-tool" --help
grep -c 'hostfwd=tcp:127.0.0.1:' "$ACE_DIR/tools/ace_run_hypervisor.sh"
grep -c 'UserKnownHostsFile=/dev/null' "$ACE_DIR/tools/common.sh"

section "9. Record the crates that were downloaded"
find "$CARGO_HOME/registry/cache" -name '*.crate' | wc -l
find "$CARGO_HOME/registry/cache" -name '*.crate' -printf '%f\n' | sort
du -sh "$CARGO_HOME"

section "10. Check the upstream tree, the shared Rust setup, and the project"
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
git status --short
git diff --stat
rustup default
rustup component list --installed --toolchain stable
cd "$PROJECT_ROOT"
git status --short
free -h


# ---------------- Logging harness: finish (not part of the procedure) -------
finish "completed"
