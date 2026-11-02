#!/usr/bin/env bash
# =============================================================================
#  IBM-ACE-On-QEMU-Reproduction
#  G08 : Build QEMU 8.2.1 for the emulated RISC-V platform (make emulator)
#
#  Steps 1-7 below are plain Linux commands, identical to docs/G08_emulator.md.
#  Uses the build settings in scripts/build_env.sh (docs/SAFETY_AUDIT.md).
#  Downloads the QEMU 8.2.1 source (about 130 MB) and compiles it with 2 jobs.
#  Stops before building if less than 4 GiB of memory is available.
#  No sudo. Nothing is pushed. One local commit is made for the reviewed G07 work.
#
#  Before running, put these seven files in ~/download:
#    G08_emulator.sh   G08_emulator.md   G07_review.md
#    SAFETY_AUDIT.md   SOURCE_PROVENANCE.md   build_env.sh   wgetrc
#
#  Usage :  bash ~/download/G08_emulator.sh        (do not use sudo)
#  Upload:  logs/review/G08_*.review.log   (masked copy)
#  Time  :  the QEMU build (step 5) takes several minutes.
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

RAW="$(mktemp "$LOG_DIR/G08_$(date -u +%Y%m%dT%H%M%SZ)_XXXXXX.raw.log")" || exit 2
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

echo "# G08 Emulator | run=$RUN_ID | input_sha256=$(sha256sum "$LOG_DIR/$RUN_ID.input.sh" | cut -d' ' -f1)"
echo "# previous gate: G07 PASS (see logs/review/G07_review.md)"
printf 'G08 Emulator (%s)\n' "$RUN_ID" >&3
set -x
# ---------------- Logging harness: end ---------------------------------------


section "1. Verify the downloaded files and all sealed evidence"
cd "$DOWNLOAD_DIR"
sha256sum G08_emulator.sh G08_emulator.md
echo "1c4b151f9e3512fe3a437ebd061d2d18d2e1b5e21da759c5a69c5bc77e70df63  G07_review.md" | sha256sum -c -
echo "6a353adb19ed00865c6e5b29bfe46098ccab0d045200aa41a78396465cb490bb  SAFETY_AUDIT.md" | sha256sum -c -
echo "30c33c4311e42358850c421265e6613770ab85a9971f189710fc6c4917c731b2  SOURCE_PROVENANCE.md" | sha256sum -c -
echo "dd8de984968d097bc882ab5f3dd47286c9fb71652864e0ec0db00a5260f90de8  build_env.sh" | sha256sum -c -
echo "ce1fecda74befd6a4c8d5bdcd3738434099975aa4ff8bc25a6cfeb577315e96f  wgetrc" | sha256sum -c -
cd "$PROJECT_ROOT/logs"
sha256sum -c *.sha256
stop_if_failed "step 1"

section "2. Commit the reviewed G07 work (local only, UTC)"
cd "$PROJECT_ROOT"
cp "$DOWNLOAD_DIR/G07_review.md" logs/review/
cp "$DOWNLOAD_DIR/SAFETY_AUDIT.md" docs/
cp "$DOWNLOAD_DIR/SOURCE_PROVENANCE.md" docs/
cp "$DOWNLOAD_DIR/build_env.sh" scripts/
cp "$DOWNLOAD_DIR/wgetrc" scripts/
git add scripts/G07_tools.sh docs/G07_tools.md docs/SAFETY_AUDIT.md docs/SOURCE_PROVENANCE.md scripts/build_env.sh scripts/wgetrc
git status --short
git diff --cached --quiet || TZ=UTC0 git commit -m "G07: ACE tools and TAP tool (make tools)"
git log -1 --format='%h  %aI  %an <%ae>  %s'
git show --stat --format= HEAD
cp "$DOWNLOAD_DIR/G08_emulator.sh" scripts/
cp "$DOWNLOAD_DIR/G08_emulator.md" docs/
stop_if_failed "step 2"

section "3. Record the host and source state, and check the free memory"
uname -r
free -h
df -h "$PROJECT_ROOT"
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
git status --short
test "$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)" -ge 4194304
stop_if_failed "step 3"

section "4. Set the build environment"
source "$PROJECT_ROOT/scripts/build_env.sh"
env | grep -E '^(ACE_DIR|QEMU_SOURCE_DIR|BR2_DL_DIR|CARGO_HOME|BR2_JLEVEL|OMP_NUM_THREADS|CARGO_BUILD_JOBS|WGETRC)=' | sort
stop_if_failed "step 4"

section "5. Build QEMU with the upstream Makefile"
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
date -u
make -j2 emulator
date -u
stop_if_failed "step 5"

section "6. Verify the emulator and record the source tarball"
Q="$ACE_DIR/qemu/bin/qemu-system-riscv64"
"$Q" --version
"$Q" -machine help | grep -w virt
"$Q" -cpu help | grep -w rv64
ldd "$Q" | grep -E 'slirp|not found'
sha256sum "$Q"
ls -l "$QEMU_SOURCE_DIR/qemu-8.2.1.tar.xz"
sha256sum "$QEMU_SOURCE_DIR/qemu-8.2.1.tar.xz"
/usr/bin/qemu-system-riscv64 --version
du -sh "$ACE_DIR/qemu" "$QEMU_SOURCE_DIR"

section "7. Check the upstream tree and the project"
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
git status --short
cd "$PROJECT_ROOT"
git status --short
free -h


# ---------------- Logging harness: finish (not part of the procedure) -------
finish "completed"
