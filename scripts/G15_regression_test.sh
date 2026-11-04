#!/usr/bin/env bash
# =============================================================================
#  IBM-ACE-On-QEMU-Reproduction
#  G15 : Run the upstream regression test (ace test), unchanged, and audit its results (E8)
#
#  Steps 1-10 below are plain Linux commands, identical to docs/G15_regression_test.md.
#  Runs "$ACE_DIR/tools/ace test" exactly as the upstream CI does (with patch 0002 in its
#  scripts), under a 15-minute limit, in a working directory inside build/. E8 is judged from
#  the result lines, not from the exit code (SAFETY_AUDIT A10). Afterwards: no QEMU of this
#  project may be left, the test logs on the hypervisor's disk are read with debugfs, and the
#  disk image is restored. Stops before the test if less than 6 GiB of memory is available.
#  No sudo. Nothing is pushed. One local commit is made for the reviewed G14 work.
#
#  Before running, put these four files in ~/download:
#    G15_regression_test.sh   G15_regression_test.md   G14_review.md   CHECKPOINT_3.md
#
#  Usage :  bash ~/download/G15_regression_test.sh        (do not use sudo)
#  Upload:  logs/review/G15_*.review.log   (masked copy)
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

RAW="$(mktemp "$LOG_DIR/G15_$(date -u +%Y%m%dT%H%M%SZ)_XXXXXX.raw.log")" || exit 2
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

echo "# G15 Regression Test | run=$RUN_ID | input_sha256=$(sha256sum "$LOG_DIR/$RUN_ID.input.sh" | cut -d' ' -f1)"
echo "# previous gate: G14 PASS (see logs/review/G14_review.md); checkpoint 3 recorded"
printf 'G15 Regression Test (%s)\n' "$RUN_ID" >&3
set -x
# ---------------- Logging harness: end ---------------------------------------


section "1. Verify the downloaded files and all sealed evidence"
cd "$DOWNLOAD_DIR"
sha256sum G15_regression_test.sh G15_regression_test.md
echo "fc40d84ce26ff4c7478dd32df22c7ea9c64d7c64adcfbb1f43bbe8f00b86ed34  G14_review.md" | sha256sum -c -
echo "9cf6ea2c64924a6a2484e3d1afa2412e0cce140b9e591639762f939a970ea950  CHECKPOINT_3.md" | sha256sum -c -
cd "$PROJECT_ROOT/logs"
sha256sum -c *.sha256
stop_if_failed "step 1"

section "2. Commit the reviewed G14 work (local only, UTC)"
cd "$PROJECT_ROOT"
cp "$DOWNLOAD_DIR/G14_review.md" logs/review/
cp "$DOWNLOAD_DIR/CHECKPOINT_3.md" logs/review/
git add scripts/G14_attestation.sh docs/G14_attestation.md
git status --short
git diff --cached --quiet || TZ=UTC0 git commit -m "G14: confidential VM, local attestation, and the demo secret; checkpoint 3"
git log -1 --format='%h  %aI  %an <%ae>  %s'
git show --stat --format= HEAD
cp "$DOWNLOAD_DIR/G15_regression_test.sh" scripts/
cp "$DOWNLOAD_DIR/G15_regression_test.md" docs/
stop_if_failed "step 2"

section "3. Check the host before the test: memory, other ACE QEMU, ports in the test's range"
source "$PROJECT_ROOT/scripts/build_env.sh"
uname -r
free -h
test "$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)" -ge 6291456
test -z "$(pgrep -u "$(id -un)" -f "$ACE_DIR/qemu/bin/qemu-system-riscv64")"
ss -ltnH | awk '{print $4}' | sed 's/.*://' | sort -un | awk '$1 >= 3000 && $1 <= 5999'
stop_if_failed "step 3"

section "4. Check that the images are the ones reviewed in G12"
FW="$ACE_DIR/security-monitor/opensbi/platform/generic/firmware/fw_payload.elf"
HV="$ACE_DIR/hypervisor/buildroot/images/rootfs.ext2"
PRISTINE="$PROJECT_ROOT/build/pristine/hypervisor-rootfs.ext2"
test "$(sha256sum < "$FW" | cut -d' ' -f1)" = 6a41b58184c3f25db92b036635abf9738df2a4b375e63c58100e313473b8c286
test "$(sha256sum < "$PRISTINE" | cut -d' ' -f1)" = cc07c2dc1d60a3c38bbacfa2a7d7e5f64cccf41d55e625027875b0242a2ceeed
test "$(sha256sum < "$HV" | cut -d' ' -f1)" = cc07c2dc1d60a3c38bbacfa2a7d7e5f64cccf41d55e625027875b0242a2ceeed
stop_if_failed "step 4"

section "5. Run the upstream regression test, unchanged"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
TEST_DIR="$PROJECT_ROOT/build/g15-test"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"
date -u
timeout 900 "$ACE_DIR/tools/ace" test && echo "ace test exit status: 0" || echo "ace test exit status: $?"
date -u

section "6. Judge the results by their lines (E8)"
cat "$TEST_DIR/.run_tests.log"
cat "$TEST_DIR/ace_test_results"
test "$(grep -c '^test_attestation: success' "$TEST_DIR/ace_test_results")" = 1
test "$(grep -c '^test_smp: success' "$TEST_DIR/ace_test_results")" = 1
test "$(grep -c ': failed' "$TEST_DIR/ace_test_results")" = 0

section "7. Check that no QEMU of this project is left"
pgrep -a -u "$(id -un)" -f "$ACE_DIR/qemu/bin/qemu-system-riscv64" | cut -c1-300 || echo "(no QEMU of this project running)"
pkill -u "$(id -un)" -f "$ACE_DIR/qemu/bin/qemu-system-riscv64" || echo "(nothing to stop)"
sleep 2
test -z "$(pgrep -u "$(id -un)" -f "$ACE_DIR/qemu/bin/qemu-system-riscv64")"

section "8. Read the test logs left on the hypervisor's disk"
debugfs -R "ls -l /root" "$HV"
debugfs -R "cat /root/test_attestation.log" "$HV"
debugfs -R "cat /root/test_smp.log" "$HV"
debugfs -R "cat /root/tmp_dmesg.log" "$HV"
debugfs -R "cat /root/tmp_smp_dmesg.log" "$HV"

section "9. Keep the results in logs/ and restore the disk image"
cp "$TEST_DIR/ace_test_results" "$PROJECT_ROOT/logs/G15_ace_test_results_$STAMP.log"
cp "$TEST_DIR/.run_tests.log" "$PROJECT_ROOT/logs/G15_run_tests_$STAMP.log"
chmod 400 "$PROJECT_ROOT/logs/G15_ace_test_results_$STAMP.log" "$PROJECT_ROOT/logs/G15_run_tests_$STAMP.log"
sha256sum "$PROJECT_ROOT/logs/G15_ace_test_results_$STAMP.log" "$PROJECT_ROOT/logs/G15_run_tests_$STAMP.log"
sha256sum "$HV"
cp "$PRISTINE" "$HV"
test "$(sha256sum < "$HV" | cut -d' ' -f1)" = cc07c2dc1d60a3c38bbacfa2a7d7e5f64cccf41d55e625027875b0242a2ceeed

section "10. Check the upstream tree and the project"
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
git status --short
cd "$PROJECT_ROOT"
git status --short
free -h


# ---------------- Logging harness: finish (not part of the procedure) -------
finish "completed"
