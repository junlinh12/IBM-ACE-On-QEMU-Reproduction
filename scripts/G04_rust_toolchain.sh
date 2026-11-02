#!/usr/bin/env bash
# =============================================================================
#  IBM-ACE-On-QEMU-Reproduction
#  G04 : Install the pinned Rust toolchain without changing the default
#
#  Steps 1-7 below are plain Linux commands, identical to docs/G04_rust_toolchain.md.
#  Adds the toolchain declared in upstream/ACE-RISCV/rust-toolchain.toml.
#  The default toolchain (used by other projects on this host) is NOT changed. No sudo.
#  One local commit is made for the reviewed G03 work. Nothing is built or pushed.
#
#  Before running, put these three files in ~/download:
#    G04_rust_toolchain.sh   G04_rust_toolchain.md   G03_review.md
#
#  Usage :  bash ~/download/G04_rust_toolchain.sh        (do not use sudo)
#  Upload:  logs/review/G04_*.review.log   (masked copy)
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

RAW="$(mktemp "$LOG_DIR/G04_$(date -u +%Y%m%dT%H%M%SZ)_XXXXXX.raw.log")" || exit 2
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

echo "# G04 Rust Toolchain | run=$RUN_ID | input_sha256=$(sha256sum "$LOG_DIR/$RUN_ID.input.sh" | cut -d' ' -f1)"
echo "# previous gate: G03 PASS (see logs/review/G03_review.md)"
printf 'G04 Rust Toolchain (%s)\n' "$RUN_ID" >&3
set -x
# ---------------- Logging harness: end ---------------------------------------


section "1. Verify the downloaded files and all sealed evidence"
cd "$DOWNLOAD_DIR"
sha256sum G04_rust_toolchain.sh G04_rust_toolchain.md
echo "fafb35fa2c704138d2c2354eb6b6cdfcc01f5fd3647261d209852ad4aa7b31eb  G03_review.md" | sha256sum -c -
cd "$PROJECT_ROOT/logs"
sha256sum -c *.sha256
stop_if_failed "step 1"

section "2. Commit the reviewed G03 work (local only, UTC)"
cd "$PROJECT_ROOT"
cp "$DOWNLOAD_DIR/G03_review.md" logs/review/
git add scripts/G03_apt_packages.sh docs/G03_apt_packages.md
git status --short
git diff --cached --quiet || TZ=UTC0 git commit -m "G03: install llvm-dev required by the upstream CI"
git log -1 --format='%h  %aI  %an <%ae>  %s'
git show --stat --format= HEAD
cp "$DOWNLOAD_DIR/G04_rust_toolchain.sh" scripts/
cp "$DOWNLOAD_DIR/G04_rust_toolchain.md" docs/
stop_if_failed "step 2"

section "3. Record the Rust state before the change"
rustup --version
rustup toolchain list
rustup default
cat "$PROJECT_ROOT/upstream/ACE-RISCV/rust-toolchain.toml"

section "4. Record which Rust tools the upstream build uses"
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
git ls-files '*rust-toolchain*' '*Cargo.toml' '*.cargo/config*'
git grep -nE 'cargo|rustup|rustc|rustfmt|clippy|objcopy' -- '*Makefile*' '*.mk' || echo "(no matches)"

section "5. Install the pinned nightly (the default is not changed)"
date -u
rustup toolchain install nightly-2026-03-23 --profile default --target riscv64gc-unknown-none-elf --component rustfmt --no-self-update
date -u
stop_if_failed "step 5"

section "6. Verify the toolchain inside and outside the upstream tree"
rustup toolchain list
rustup default
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
rustup show active-toolchain
rustc --version
cargo --version
rustup target list --installed
rustup component list --installed
cd "$PROJECT_ROOT"
rustup show active-toolchain
rustc --version

section "7. Check the project repository"
cd "$PROJECT_ROOT"
git status --short
git log --format='%h  %aI  %s'


# ---------------- Logging harness: finish (not part of the procedure) -------
finish "completed"
