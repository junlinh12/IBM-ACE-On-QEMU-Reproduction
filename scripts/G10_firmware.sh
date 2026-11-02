#!/usr/bin/env bash
# =============================================================================
#  IBM-ACE-On-QEMU-Reproduction
#  G10 : Build the firmware: OpenSBI with the ACE security monitor (make firmware)
#
#  Steps 1-11 below are plain Linux commands, identical to docs/G10_firmware.md.
#  Uses the build settings in scripts/build_env.sh (docs/SAFETY_AUDIT.md).
#  Builds the security monitor (Rust, nightly-2026-03-23) and OpenSBI, with the hypervisor
#  kernel from G09 as payload. By upstream design the build runs "cargo fmt" and patches the
#  OpenSBI submodule (SAFETY_AUDIT A11); both are recorded.
#  Stops before building if less than 4 GiB of memory or 10 GB of disk is available.
#  No sudo. Nothing is pushed. One local commit is made for the reviewed G09 work.
#
#  Before running, put these five files in ~/download:
#    G10_firmware.sh   G10_firmware.md   G09_review.md   CHECKPOINT_2.md   SOURCE_PROVENANCE.md
#
#  Usage :  bash ~/download/G10_firmware.sh        (do not use sudo)
#  Upload:  logs/review/G10_*.review.log   (masked copy)
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

RAW="$(mktemp "$LOG_DIR/G10_$(date -u +%Y%m%dT%H%M%SZ)_XXXXXX.raw.log")" || exit 2
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

echo "# G10 Firmware | run=$RUN_ID | input_sha256=$(sha256sum "$LOG_DIR/$RUN_ID.input.sh" | cut -d' ' -f1)"
echo "# previous gate: G09 PASS (see logs/review/G09_review.md); checkpoint 2 recorded"
printf 'G10 Firmware (%s)\n' "$RUN_ID" >&3
set -x
# ---------------- Logging harness: end ---------------------------------------


section "1. Verify the downloaded files and all sealed evidence"
cd "$DOWNLOAD_DIR"
sha256sum G10_firmware.sh G10_firmware.md
echo "8179cb84db36612bf18abb04bfc8c15a8f22f39c64795f2da1511eaca0cf6460  G09_review.md" | sha256sum -c -
echo "bf27d43b93345614ef33377434112e8be654b445cd89f64ba708fe6107cb48e6  CHECKPOINT_2.md" | sha256sum -c -
echo "8221db40fb40e93f7539dd4234b0cc5b2cb7c45338c8576de3ec0da21f11293c  SOURCE_PROVENANCE.md" | sha256sum -c -
cd "$PROJECT_ROOT/logs"
sha256sum -c *.sha256
stop_if_failed "step 1"

section "2. Commit the reviewed G09 work (local only, UTC)"
cd "$PROJECT_ROOT"
cp "$DOWNLOAD_DIR/G09_review.md" logs/review/
cp "$DOWNLOAD_DIR/CHECKPOINT_2.md" logs/review/
cp "$DOWNLOAD_DIR/SOURCE_PROVENANCE.md" docs/
git add scripts/G09_hypervisor.sh docs/G09_hypervisor.md docs/SOURCE_PROVENANCE.md
git status --short
git diff --cached --quiet || TZ=UTC0 git commit -m "G09: hypervisor image (make hypervisor); checkpoint 2"
git log -1 --format='%h  %aI  %an <%ae>  %s'
git show --stat --format= HEAD
cp "$DOWNLOAD_DIR/G10_firmware.sh" scripts/
cp "$DOWNLOAD_DIR/G10_firmware.md" docs/
stop_if_failed "step 2"

section "3. Record the host and source state, and check memory and disk"
uname -r
free -h
df -h "$PROJECT_ROOT"
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
git status --short
test "$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)" -ge 4194304
test "$(df -BG --output=avail "$PROJECT_ROOT" | tail -n 1 | tr -dc '0-9')" -ge 10
stop_if_failed "step 3"

section "4. Set the build environment"
source "$PROJECT_ROOT/scripts/build_env.sh"
env | grep -E '^(ACE_DIR|QEMU_SOURCE_DIR|BR2_DL_DIR|CARGO_HOME|BR2_JLEVEL|OMP_NUM_THREADS|CARGO_BUILD_JOBS|WGETRC)=' | sort
stop_if_failed "step 4"

section "5. Record the compiler Buildroot used for the hypervisor (G09 follow-up)"
GCC_BR="$(find "$ACE_DIR/hypervisor/buildroot" -maxdepth 7 -path '*/bin/*-linux-gnu-gcc' -print -quit)"
echo "$GCC_BR"
"$GCC_BR" --version
grep -a -o -m 1 'Linux version [[:print:]]*' "$ACE_DIR/hypervisor/buildroot/images/Image"

section "6. Check the Rust toolchain and the payload before the build"
cd "$PROJECT_ROOT/upstream/ACE-RISCV/security-monitor"
echo "RUSTUP_TOOLCHAIN=${RUSTUP_TOOLCHAIN:-<not set>}"
rustup show active-toolchain
rustc --version
cargo fmt --version
rustup target list --installed
git -C opensbi status --short
grep -c ace_setup_this_hart opensbi/lib/sbi/sbi_hsm.c || echo "(OpenSBI not patched)"
test "$(sha256sum < "$ACE_DIR/hypervisor/buildroot/images/Image" | cut -d' ' -f1)" = 75a0db25e8f28f415d93b490bbaf4f1bf4b31b6c22685556bfe32adf056308d7
stop_if_failed "step 6"

section "7. Build the firmware with the upstream Makefile"
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
date -u
make -j2 firmware
date -u
stop_if_failed "step 7"

section "8. Verify the firmware and the security monitor"
FW="$ACE_DIR/security-monitor/opensbi/platform/generic/firmware"
ls -l "$FW"
file "$FW/fw_payload.elf"
sha256sum "$FW/fw_payload.elf" "$FW/fw_payload.bin"
ls -l "$ACE_DIR/security-monitor/libace.a"
sha256sum "$ACE_DIR/security-monitor/libace.a"

section "9. Check that the firmware carries the G09 hypervisor kernel"
python3 -c 'import sys; fw = open(sys.argv[1], "rb").read(); img = open(sys.argv[2], "rb").read(); i = fw.find(img); print("payload offset:", hex(i) if i >= 0 else "NOT FOUND"); sys.exit(i < 0)' "$FW/fw_payload.bin" "$ACE_DIR/hypervisor/buildroot/images/Image"

section "10. Record the crates that were downloaded"
find "$CARGO_HOME/registry/cache" -name '*.crate' | wc -l
find "$CARGO_HOME/registry/cache" -name '*.crate' -printf '%f\n' | sort

section "11. Record the changes the build made to the upstream tree"
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
git status --short
git diff --stat
git -C security-monitor/opensbi status --short
git -C security-monitor/opensbi diff --stat
grep -c ace_setup_this_hart security-monitor/opensbi/lib/sbi/sbi_hsm.c
cd "$PROJECT_ROOT"
git status --short
free -h
df -h "$PROJECT_ROOT"


# ---------------- Logging harness: finish (not part of the procedure) -------
finish "completed"
