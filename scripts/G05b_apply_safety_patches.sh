#!/usr/bin/env bash
# =============================================================================
#  IBM-ACE-On-QEMU-Reproduction
#  G05b : Record the remaining audit evidence and apply the safety patches
#
#  Steps 1-8 below are plain Linux commands, identical to docs/G05b_apply_safety_patches.md.
#  Applies patches/0001 and patches/0002 (see docs/SAFETY_AUDIT.md) to upstream/ACE-RISCV.
#  Nothing is built, run, installed, or pushed. No sudo.
#  One local commit is made for the reviewed G05 (read-only) work.
#
#  Before running, put these seven files in ~/download:
#    G05b_apply_safety_patches.sh   G05b_apply_safety_patches.md
#    G05_review.md   SAFETY_AUDIT.md   PATCHES_README.md
#    0001-build-parallelism.patch   0002-run-scripts-host-safety.patch
#
#  Usage :  bash ~/download/G05b_apply_safety_patches.sh        (do not use sudo)
#  Upload:  logs/review/G05b_*.review.log   (masked copy)
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

RAW="$(mktemp "$LOG_DIR/G05b_$(date -u +%Y%m%dT%H%M%SZ)_XXXXXX.raw.log")" || exit 2
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

echo "# G05b Apply Safety Patches | run=$RUN_ID | input_sha256=$(sha256sum "$LOG_DIR/$RUN_ID.input.sh" | cut -d' ' -f1)"
echo "# previous gate: G05 read-only audit PASS (see logs/review/G05_review.md)"
printf 'G05b Apply Safety Patches (%s)\n' "$RUN_ID" >&3
set -x
# ---------------- Logging harness: end ---------------------------------------


section "1. Verify the downloaded files and all sealed evidence"
cd "$DOWNLOAD_DIR"
sha256sum G05b_apply_safety_patches.sh G05b_apply_safety_patches.md
echo "770d636225cc42ba9954513dfcb426db343131c49b68761db2b9ebb562db8956  G05_review.md" | sha256sum -c -
echo "4c2de2f2ffec80da8639932f292510dcd1f44f358f3373fd9ee2a9083fb8fe38  SAFETY_AUDIT.md" | sha256sum -c -
echo "8ce96558b74c5019087e8cc79f166d534dbb40fa67cfe88426c8fdef063cf7e5  PATCHES_README.md" | sha256sum -c -
echo "cf83fb0b058c47958b9767be45673780ecd34de044bc89cf723fe4dcbe68f69a  0001-build-parallelism.patch" | sha256sum -c -
echo "2aeadce13855d1d518ec267d2f5ee9f6164849751583495c022e2f1fd0faf503  0002-run-scripts-host-safety.patch" | sha256sum -c -
cd "$PROJECT_ROOT/logs"
sha256sum -c *.sha256
stop_if_failed "step 1"

section "2. Commit the reviewed G05 read-only work (local only, UTC)"
cd "$PROJECT_ROOT"
cp "$DOWNLOAD_DIR/G05_review.md" logs/review/
git add scripts/G05_audit_build_scripts.sh docs/G05_audit_build_scripts.md
git status --short
git diff --cached --quiet || TZ=UTC0 git commit -m "G05: audit upstream build and run scripts (read-only)"
git log -1 --format='%h  %aI  %an <%ae>  %s'
git show --stat --format= HEAD
cp "$DOWNLOAD_DIR/G05b_apply_safety_patches.sh" scripts/
cp "$DOWNLOAD_DIR/G05b_apply_safety_patches.md" docs/
stop_if_failed "step 2"

section "3. Record the test scripts and Buildroot configurations"
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
git ls-files -z -- hypervisor/rootfs confidential-vms/linux_vm/hypervisor_rootfs | xargs -0 -r grep -IHn ''
grep -IHn '' hypervisor/configurations/qemu_riscv64_virt_defconfig confidential-vms/linux_vm/configurations/qemu_riscv64_virt_defconfig
stop_if_failed "step 3"

section "4. Install the patches and the audit into the project"
cd "$PROJECT_ROOT"
cp "$DOWNLOAD_DIR/0001-build-parallelism.patch" patches/
cp "$DOWNLOAD_DIR/0002-run-scripts-host-safety.patch" patches/
cp "$DOWNLOAD_DIR/PATCHES_README.md" patches/README.md
cp "$DOWNLOAD_DIR/SAFETY_AUDIT.md" docs/
sha256sum patches/*
stop_if_failed "step 4"

section "5. Check the patches against the pinned sources"
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
git rev-parse HEAD
git ls-tree HEAD hypervisor/Makefile confidential-vms/linux_vm/Makefile security-monitor/Makefile tools/ace_run_hypervisor.sh tools/common.sh
git apply --reverse --check "$PROJECT_ROOT/patches/0001-build-parallelism.patch" 2>/dev/null || git apply --check "$PROJECT_ROOT/patches/0001-build-parallelism.patch"
git apply --reverse --check "$PROJECT_ROOT/patches/0002-run-scripts-host-safety.patch" 2>/dev/null || git apply --check "$PROJECT_ROOT/patches/0002-run-scripts-host-safety.patch"
stop_if_failed "step 5"

section "6. Apply the patches"
git apply --reverse --check "$PROJECT_ROOT/patches/0001-build-parallelism.patch" 2>/dev/null || git apply "$PROJECT_ROOT/patches/0001-build-parallelism.patch"
git apply --reverse --check "$PROJECT_ROOT/patches/0002-run-scripts-host-safety.patch" 2>/dev/null || git apply "$PROJECT_ROOT/patches/0002-run-scripts-host-safety.patch"
git apply --reverse --check "$PROJECT_ROOT/patches/0001-build-parallelism.patch"
git apply --reverse --check "$PROJECT_ROOT/patches/0002-run-scripts-host-safety.patch"
stop_if_failed "step 6"

section "7. Record the patched state"
git status --short
git diff --stat
git diff
grep -n 'BR2_JLEVEL\|nproc' hypervisor/Makefile confidential-vms/linux_vm/Makefile security-monitor/Makefile
OMP_NUM_THREADS=2 nproc

section "8. Check the project repository"
cd "$PROJECT_ROOT"
git status --short


# ---------------- Logging harness: finish (not part of the procedure) -------
finish "completed"
