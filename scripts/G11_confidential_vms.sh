#!/usr/bin/env bash
# =============================================================================
#  IBM-ACE-On-QEMU-Reproduction
#  G11 : Build the confidential VM and repack the hypervisor (make confidential_vms)
#
#  Steps 1-11 below are plain Linux commands, identical to docs/G11_confidential_vms.md.
#  Uses the build settings in scripts/build_env.sh (docs/SAFETY_AUDIT.md).
#  Builds the confidential VM (Buildroot: kernel, root file system, ace.ko), its TAPs,
#  dtc and kvmtool (cloned from git.kernel.org and GitHub), and repacks the hypervisor root
#  file system. RUSTUP_TOOLCHAIN=1.98.1 is set for this make only, because the "tools"
#  prerequisite runs "cargo fmt" for the TAP tool (same reason and check as G07).
#  Stops before building if less than 4 GiB of memory or 30 GB of disk is available.
#  Harness change from G11: an EXIT trap seals the log even if the shell stops unexpectedly.
#  No sudo. Nothing is pushed. One local commit is made for the reviewed G10 work.
#
#  Before running, put these three files in ~/download:
#    G11_confidential_vms.sh   G11_confidential_vms.md   G10_review.md
#
#  Usage :  bash ~/download/G11_confidential_vms.sh        (do not use sudo)
#           Recommended: run it inside tmux.
#  Upload:  logs/review/G11_*.review.log   (masked copy)
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

RAW="$(mktemp "$LOG_DIR/G11_$(date -u +%Y%m%dT%H%M%SZ)_XXXXXX.raw.log")" || exit 2
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

echo "# G11 Confidential VMs | run=$RUN_ID | input_sha256=$(sha256sum "$LOG_DIR/$RUN_ID.input.sh" | cut -d' ' -f1)"
echo "# previous gate: G10 PASS (see logs/review/G10_review.md)"
printf 'G11 Confidential VMs (%s)\n' "$RUN_ID" >&3
set -x
# ---------------- Logging harness: end ---------------------------------------


section "1. Verify the downloaded files and all sealed evidence"
cd "$DOWNLOAD_DIR"
sha256sum G11_confidential_vms.sh G11_confidential_vms.md
echo "6f56d0f0247bf57bf9275cd5ded32487a0718f25989d2af56eb4b73263e222db  G10_review.md" | sha256sum -c -
cd "$PROJECT_ROOT/logs"
sha256sum -c *.sha256
stop_if_failed "step 1"

section "2. Commit the reviewed G10 work (local only, UTC)"
cd "$PROJECT_ROOT"
cp "$DOWNLOAD_DIR/G10_review.md" logs/review/
git add scripts/G10_firmware.sh docs/G10_firmware.md
git status --short
git diff --cached --quiet || TZ=UTC0 git commit -m "G10: OpenSBI with the ACE security monitor (make firmware)"
git log -1 --format='%h  %aI  %an <%ae>  %s'
git show --stat --format= HEAD
cp "$DOWNLOAD_DIR/G11_confidential_vms.sh" scripts/
cp "$DOWNLOAD_DIR/G11_confidential_vms.md" docs/
stop_if_failed "step 2"

section "3. Record the host and source state, and check memory and disk"
uname -r
free -h
df -h "$PROJECT_ROOT"
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
git status --short
test "$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)" -ge 4194304
test "$(df -BG --output=avail "$PROJECT_ROOT" | tail -n 1 | tr -dc '0-9')" -ge 30
stop_if_failed "step 3"

section "4. Set the build environment and record the files that will change"
source "$PROJECT_ROOT/scripts/build_env.sh"
env | grep -E '^(ACE_DIR|QEMU_SOURCE_DIR|BR2_DL_DIR|CARGO_HOME|BR2_JLEVEL|OMP_NUM_THREADS|CARGO_BUILD_JOBS|WGETRC)=' | sort
sha256sum "$ACE_DIR/hypervisor/buildroot/images/rootfs.ext2" "$ACE_DIR/tools/cove-tap-tool"
stop_if_failed "step 4"

section "5. Build the confidential VM with the upstream Makefile"
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
export RUSTUP_TOOLCHAIN=1.98.1
test "$(rustup run stable rustc --version)" = "$(rustc --version)"
date -u
make -j2 confidential_vms
date -u
unset RUSTUP_TOOLCHAIN
stop_if_failed "step 5"

section "6. Verify the confidential VM"
CVM="$ACE_DIR/confidential_vms/linux_vm/buildroot"
ls -l "$CVM/images"
sha256sum "$CVM/images/Image" "$CVM/images/rootfs.ext2"
grep -a -o -m 1 'Linux version [[:print:]]*' "$CVM/images/Image"
cat "$CVM"/build/linux-[0-9]*/.applied_patches_list
grep -E '^CONFIG_(RISCV_COVE[A-Z_]*|MODULES)=' "$CVM"/build/linux-[0-9]*/.config
find "$ACE_DIR/confidential_vms/linux_vm/overlay" -name '*.ko' -exec sha256sum {} +

section "7. Record the TAPs and the measurements they contain"
ls -l "$CVM/images/cove_tap_qemu" "$CVM/images/cove_tap_kvmtool"
sha256sum "$CVM/images/cove_tap_qemu" "$CVM/images/cove_tap_kvmtool"
"$ACE_DIR/tools/cove-tap-tool" measure --base-address=0x80000000 --kernel-file="$CVM/images/Image"
"$ACE_DIR/tools/cove-tap-tool" measure --base-address=0x80200000 --kernel-file="$CVM/images/Image"
sha256sum "$ACE_DIR/tools/cove-tap-tool"

section "8. Record dtc and kvmtool"
K="$ACE_DIR/hypervisor/kvmtool"
git -C "$K/dtc" remote get-url origin
git -C "$K/dtc" log -1 --format='%H %cI %s'
git -C "$K/kvmtool" remote get-url origin
git -C "$K/kvmtool" rev-parse --abbrev-ref HEAD
git -C "$K/kvmtool" log -1 --format='%H %cI %s'
file "$K/kvmtool/lkvm-static"
sha256sum "$K/kvmtool/lkvm-static"

section "9. Check the repacked hypervisor root file system"
find "$ACE_DIR/hypervisor/overlay" -type f | sort
sha256sum "$ACE_DIR/hypervisor/overlay/root/linux_vm/"*
sha256sum "$ACE_DIR/hypervisor/buildroot/images/rootfs.ext2"
sha256sum "$CVM/images/rootfs.ext2" "$ACE_DIR/hypervisor/overlay/root/linux_vm/rootfs.ext2"

section "10. Record the downloaded sources"
ls "$BR2_DL_DIR"
find "$BR2_DL_DIR" -mindepth 2 -maxdepth 2 -type f ! -name .lock -exec sha256sum {} + | sort -k 2
du -sh "$BR2_DL_DIR" "$ACE_DIR/confidential_vms" "$ACE_DIR/hypervisor"

section "11. Check the upstream tree and the project"
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
git status --short
git diff --stat
git -C hypervisor/buildroot status --short
cd "$PROJECT_ROOT"
git status --short
free -h
df -h "$PROJECT_ROOT"


# ---------------- Logging harness: finish (not part of the procedure) -------
finish "completed"
