#!/usr/bin/env bash
# =============================================================================
#  IBM-ACE-On-QEMU-Reproduction
#  G06 : Build the RISC-V GNU toolchain (make devtools)
#
#  Steps 1-9 below are plain Linux commands, identical to docs/G06_devtools.md.
#  Uses the build settings in scripts/build_env.sh (docs/SAFETY_AUDIT.md).
#  Downloads the toolchain release tarball (about 0.3-0.5 GB, twice: once to record its
#  SHA-256, once by the upstream Makefile). No sudo. Nothing is pushed.
#  One local commit is made for the reviewed G05b work.
#
#  Before running, put these six files in ~/download:
#    G06_devtools.sh   G06_devtools.md   G05b_review.md
#    SOURCE_PROVENANCE.md   build_env.sh   0002-run-scripts-host-safety.patch (revision 2)
#
#  Usage :  bash ~/download/G06_devtools.sh        (do not use sudo)
#  Upload:  logs/review/G06_*.review.log   (masked copy)
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

RAW="$(mktemp "$LOG_DIR/G06_$(date -u +%Y%m%dT%H%M%SZ)_XXXXXX.raw.log")" || exit 2
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

echo "# G06 Devtools | run=$RUN_ID | input_sha256=$(sha256sum "$LOG_DIR/$RUN_ID.input.sh" | cut -d' ' -f1)"
echo "# previous gate: G05b PASS (see logs/review/G05b_review.md)"
printf 'G06 Devtools (%s)\n' "$RUN_ID" >&3
set -x
# ---------------- Logging harness: end ---------------------------------------


section "1. Verify the downloaded files and all sealed evidence"
cd "$DOWNLOAD_DIR"
sha256sum G06_devtools.sh G06_devtools.md
echo "71806155032f5c9dc97e6838df1453950cc1c4c9a87c7a80cd0d0357c5ae1c2e  G05b_review.md" | sha256sum -c -
echo "19d484b204f189fb65d985d06369b9439c466ce5c6916d373fd58d58e80d71b0  SOURCE_PROVENANCE.md" | sha256sum -c -
echo "5f73a4dc30e4712afc863b78e7bc1d1fc70a71bf441540ae0e585364aefb771d  build_env.sh" | sha256sum -c -
echo "3064e443ade7f24b46d5a85179afc94bf8fce1e0046a4581ea9e9549f8ed869b  0002-run-scripts-host-safety.patch" | sha256sum -c -
cd "$PROJECT_ROOT/logs"
sha256sum -c *.sha256
stop_if_failed "step 1"

section "2. Install revision 2 of patch 0002 and confirm both patches are applied"
cd "$PROJECT_ROOT"
cp "$DOWNLOAD_DIR/0002-run-scripts-host-safety.patch" patches/
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
git apply --reverse --check "$PROJECT_ROOT/patches/0001-build-parallelism.patch"
git apply --reverse --check "$PROJECT_ROOT/patches/0002-run-scripts-host-safety.patch"
stop_if_failed "step 2"

section "3. Commit the reviewed G05b work (local only, UTC)"
cd "$PROJECT_ROOT"
cp "$DOWNLOAD_DIR/G05b_review.md" logs/review/
cp "$DOWNLOAD_DIR/SOURCE_PROVENANCE.md" docs/
cp "$DOWNLOAD_DIR/build_env.sh" scripts/
git add scripts/G05b_apply_safety_patches.sh docs/G05b_apply_safety_patches.md docs/SAFETY_AUDIT.md docs/SOURCE_PROVENANCE.md patches/README.md patches/0001-build-parallelism.patch patches/0002-run-scripts-host-safety.patch scripts/build_env.sh
git status --short
git diff --cached --quiet || TZ=UTC0 git commit -m "G05b: safety patches for build parallelism and run scripts"
git log -1 --format='%h  %aI  %an <%ae>  %s'
git show --stat --format= HEAD
cp "$DOWNLOAD_DIR/G06_devtools.sh" scripts/
cp "$DOWNLOAD_DIR/G06_devtools.md" docs/
stop_if_failed "step 3"

section "4. Record the host and source state before the build"
uname -r
free -h
df -h "$PROJECT_ROOT"
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
git status --short

section "5. Set the build environment"
source "$PROJECT_ROOT/scripts/build_env.sh"
env | grep -E '^(ACE_DIR|QEMU_SOURCE_DIR|BR2_DL_DIR|CARGO_HOME|BR2_JLEVEL|OMP_NUM_THREADS|CARGO_BUILD_JOBS)=' | sort
mkdir -p "$ACE_DIR" "$QEMU_SOURCE_DIR" "$BR2_DL_DIR" "$CARGO_HOME" "$PROJECT_ROOT/build/downloads"
stop_if_failed "step 5"

section "6. Download the toolchain tarball and record its SHA-256"
cd "$PROJECT_ROOT/build/downloads"
TOOLCHAIN=riscv64-glibc-ubuntu-22.04-gcc-nightly-2023.09.27-nightly.tar.gz
[ -f "$TOOLCHAIN" ] || { wget -q -O "$TOOLCHAIN.part" "https://github.com/riscv-collab/riscv-gnu-toolchain/releases/download/2023.09.27/$TOOLCHAIN" && mv "$TOOLCHAIN.part" "$TOOLCHAIN"; }
ls -l "$TOOLCHAIN"
sha256sum "$TOOLCHAIN"
stop_if_failed "step 6"

section "7. Build the toolchain with the upstream Makefile"
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
date -u
make -j2 devtools
date -u
stop_if_failed "step 7"

section "8. Verify the installed toolchain"
cd "$ACE_DIR/riscv-gnu-toolchain"
ls bin | wc -l
./bin/riscv64-unknown-linux-gnu-gcc --version
./bin/riscv64-unknown-linux-gnu-gcc -dumpversion
./bin/riscv64-unknown-linux-gnu-gcc -dumpmachine
find . -path '*/usr/include/linux/version.h' -exec grep -H 'LINUX_VERSION_CODE' {} +
sha256sum bin/riscv64-unknown-linux-gnu-gcc
tar -xzOf "$PROJECT_ROOT/build/downloads/$TOOLCHAIN" riscv/bin/riscv64-unknown-linux-gnu-gcc | sha256sum
du -sh .

section "9. Check the upstream tree and the project"
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
git status --short
ls *.tar.gz 2>/dev/null || echo "(no leftover tarball)"
cd "$PROJECT_ROOT"
git status --short
git check-ignore -v build/ace
free -h


# ---------------- Logging harness: finish (not part of the procedure) -------
finish "completed"
