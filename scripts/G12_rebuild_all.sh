#!/usr/bin/env bash
# =============================================================================
#  IBM-ACE-On-QEMU-Reproduction
#  G12 : Integrated rebuild ("rebuild all" of the upstream CI) and end-to-end artifact audit
#
#  Steps 1-10 below are plain Linux commands, identical to docs/G12_rebuild_all.md.
#  Runs the four targets of the upstream "all" target in its order: emulator, tools, firmware,
#  confidential_vms. RUSTUP_TOOLCHAIN=1.98.1 is set only for tools and confidential_vms (the TAP
#  tool's "cargo fmt"); firmware keeps the pinned nightly. Then reads the hypervisor root file
#  system that G13 will boot, without root, with debugfs, and checks what it carries.
#  Stops before building if less than 4 GiB of memory or 10 GB of disk is available.
#  No sudo. Nothing is pushed. One local commit is made for the reviewed G11 work.
#
#  Before running, put these four files in ~/download:
#    G12_rebuild_all.sh   G12_rebuild_all.md   G11_review.md   SOURCE_PROVENANCE.md
#
#  Usage :  bash ~/download/G12_rebuild_all.sh        (do not use sudo)
#  Upload:  logs/review/G12_*.review.log   (masked copy)
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

RAW="$(mktemp "$LOG_DIR/G12_$(date -u +%Y%m%dT%H%M%SZ)_XXXXXX.raw.log")" || exit 2
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

echo "# G12 Rebuild All | run=$RUN_ID | input_sha256=$(sha256sum "$LOG_DIR/$RUN_ID.input.sh" | cut -d' ' -f1)"
echo "# previous gate: G11 PASS (see logs/review/G11_review.md)"
printf 'G12 Rebuild All (%s)\n' "$RUN_ID" >&3
set -x
# ---------------- Logging harness: end ---------------------------------------


section "1. Verify the downloaded files and all sealed evidence"
cd "$DOWNLOAD_DIR"
sha256sum G12_rebuild_all.sh G12_rebuild_all.md
echo "1e3c0a3459d845666ca01f97f5f8be5b4284cae50ff66b12d6cf2659f56285b8  G11_review.md" | sha256sum -c -
echo "e3639f17752b4e0452d53b3d9f67298b0315ed36fa93d375cb037f068723199f  SOURCE_PROVENANCE.md" | sha256sum -c -
cd "$PROJECT_ROOT/logs"
sha256sum -c *.sha256
stop_if_failed "step 1"

section "2. Commit the reviewed G11 work (local only, UTC)"
cd "$PROJECT_ROOT"
cp "$DOWNLOAD_DIR/G11_review.md" logs/review/
cp "$DOWNLOAD_DIR/SOURCE_PROVENANCE.md" docs/
git add scripts/G11_confidential_vms.sh docs/G11_confidential_vms.md docs/SOURCE_PROVENANCE.md
git status --short
git diff --cached --quiet || TZ=UTC0 git commit -m "G11: confidential VM, TAPs, kvmtool (make confidential_vms)"
git log -1 --format='%h  %aI  %an <%ae>  %s'
git show --stat --format= HEAD
cp "$DOWNLOAD_DIR/G12_rebuild_all.sh" scripts/
cp "$DOWNLOAD_DIR/G12_rebuild_all.md" docs/
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

section "4. Set the build environment and record the images before the rebuild"
source "$PROJECT_ROOT/scripts/build_env.sh"
env | grep -E '^(ACE_DIR|QEMU_SOURCE_DIR|BR2_DL_DIR|CARGO_HOME|BR2_JLEVEL|OMP_NUM_THREADS|CARGO_BUILD_JOBS|WGETRC)=' | sort
FW="$ACE_DIR/security-monitor/opensbi/platform/generic/firmware"
CVM="$ACE_DIR/confidential_vms/linux_vm/buildroot/images"
OV="$ACE_DIR/hypervisor/overlay/root/linux_vm"
HV="$ACE_DIR/hypervisor/buildroot/images/rootfs.ext2"
sha256sum "$FW/fw_payload.elf" "$ACE_DIR/security-monitor/libace.a" "$HV" "$CVM/rootfs.ext2" "$OV/rootfs.ext2" "$CVM/cove_tap_qemu" "$CVM/cove_tap_kvmtool"
stop_if_failed "step 4"

section "5. Check that Rust 1.98.1 still equals the host's stable"
test "$(rustup run stable rustc --version)" = "$(RUSTUP_TOOLCHAIN=1.98.1 rustc --version)"
stop_if_failed "step 5"

section "6. Rebuild all targets in the order of the upstream all target"
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
date -u
make -j2 emulator
stop_if_failed "step 6 (emulator)"
RUSTUP_TOOLCHAIN=1.98.1 make -j2 tools
stop_if_failed "step 6 (tools)"
make -j2 firmware
stop_if_failed "step 6 (firmware)"
RUSTUP_TOOLCHAIN=1.98.1 make -j2 confidential_vms
date -u
stop_if_failed "step 6 (confidential_vms)"

section "7. Verify the firmware and its payload"
sha256sum "$FW/fw_payload.elf" "$FW/fw_payload.bin" "$ACE_DIR/security-monitor/libace.a"
test "$(sha256sum < "$ACE_DIR/hypervisor/buildroot/images/Image" | cut -d' ' -f1)" = 75a0db25e8f28f415d93b490bbaf4f1bf4b31b6c22685556bfe32adf056308d7
python3 -c 'import sys; fw = open(sys.argv[1], "rb").read(); img = open(sys.argv[2], "rb").read(); i = fw.find(img); print("payload offset:", hex(i) if i >= 0 else "NOT FOUND"); sys.exit(i < 0)' "$FW/fw_payload.bin" "$ACE_DIR/hypervisor/buildroot/images/Image"

section "8. Read the confidential VM back out of the hypervisor root file system"
CHK="$PROJECT_ROOT/build/g12-check"
rm -rf "$CHK"
mkdir -p "$CHK"
debugfs -R "ls -l /root" "$HV"
debugfs -R "dump /root/linux_vm/Image $CHK/Image" "$HV"
debugfs -R "dump /root/linux_vm/rootfs.ext2 $CHK/rootfs.ext2" "$HV"
debugfs -R "dump /root/linux_vm/cove_tap_qemu $CHK/cove_tap_qemu" "$HV"
debugfs -R "dump /root/linux_vm/cove_tap_kvmtool $CHK/cove_tap_kvmtool" "$HV"
sha256sum "$CHK"/* "$CVM/Image" "$CVM/cove_tap_qemu" "$CVM/cove_tap_kvmtool" "$OV/rootfs.ext2" "$CVM/rootfs.ext2"
cmp "$CHK/Image" "$CVM/Image"
cmp "$CHK/cove_tap_qemu" "$CVM/cove_tap_qemu"
cmp "$CHK/cove_tap_kvmtool" "$CVM/cove_tap_kvmtool"
cmp "$CHK/rootfs.ext2" "$OV/rootfs.ext2"

section "9. Check that the carried VM disk contains ace.ko"
debugfs -R "ls -l /root/ace_module" "$CHK/rootfs.ext2"
debugfs -R "dump /root/ace_module/ace.ko $CHK/ace.ko" "$CHK/rootfs.ext2"
sha256sum "$CHK/ace.ko" "$ACE_DIR/confidential_vms/linux_vm/overlay/root/ace_module/ace.ko"
test -s "$CHK/ace.ko"
"$ACE_DIR/tools/cove-tap-tool" measure --base-address=0x80000000 --kernel-file="$CHK/Image"
"$ACE_DIR/tools/cove-tap-tool" measure --base-address=0x80200000 --kernel-file="$CHK/Image"

section "10. Record the final images and check the upstream tree and the project"
sha256sum "$HV" "$FW/fw_payload.elf"
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
