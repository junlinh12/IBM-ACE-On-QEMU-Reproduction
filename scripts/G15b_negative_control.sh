#!/usr/bin/env bash
# =============================================================================
#  IBM-ACE-On-QEMU-Reproduction
#  G15b : Negative control of the local attestation (a TAP with a wrong PCR 4)
#
#  Steps 1-13 below are plain Linux commands, identical to docs/G15b_negative_control.md.
#  A controlled experiment in one boot of the hypervisor: the confidential VM is started twice
#  with the upstream run script; only the TAP differs. Negative run: a TAP generated exactly as
#  upstream but with PCR 4 changed in its last hex digit; the secret must NOT be released.
#  Positive run: the original TAP restored (checked byte for byte); the secret must be released.
#  Only the QEMU started here is ever stopped; the disk image is restored afterwards.
#  Stops before booting if less than 6 GiB of memory is available or the port is in use.
#  No sudo. Nothing is pushed. One local commit is made for the reviewed G15 work.
#
#  Before running, put these three files in ~/download:
#    G15b_negative_control.sh   G15b_negative_control.md   G15_review.md
#
#  Usage :  bash ~/download/G15b_negative_control.sh        (do not use sudo)
#  Upload:  logs/review/G15b_*.review.log   (masked copy)
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

RAW="$(mktemp "$LOG_DIR/G15b_$(date -u +%Y%m%dT%H%M%SZ)_XXXXXX.raw.log")" || exit 2
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

echo "# G15b Negative Control | run=$RUN_ID | input_sha256=$(sha256sum "$LOG_DIR/$RUN_ID.input.sh" | cut -d' ' -f1)"
echo "# previous gate: G15 PASS (see logs/review/G15_review.md)"
printf 'G15b Negative Control (%s)\n' "$RUN_ID" >&3
set -x
# ---------------- Logging harness: end ---------------------------------------


section "1. Verify the downloaded files and all sealed evidence"
cd "$DOWNLOAD_DIR"
sha256sum G15b_negative_control.sh G15b_negative_control.md
echo "329eefff908d59b7ff74c887c48a04a9c725de10ebc0c6e4cf9063f420298d8c  G15_review.md" | sha256sum -c -
cd "$PROJECT_ROOT/logs"
sha256sum -c *.sha256
stop_if_failed "step 1"

section "2. Commit the reviewed G15 work (local only, UTC)"
cd "$PROJECT_ROOT"
cp "$DOWNLOAD_DIR/G15_review.md" logs/review/
git add scripts/G15_regression_test.sh docs/G15_regression_test.md
git status --short
git diff --cached --quiet || TZ=UTC0 git commit -m "G15: upstream regression test (ace test), unchanged"
git log -1 --format='%h  %aI  %an <%ae>  %s'
git show --stat --format= HEAD
cp "$DOWNLOAD_DIR/G15b_negative_control.sh" scripts/
cp "$DOWNLOAD_DIR/G15b_negative_control.md" docs/
stop_if_failed "step 2"

section "3. Check the host before booting: memory, port, other ACE QEMU"
source "$PROJECT_ROOT/scripts/build_env.sh"
PORT=4022
uname -r
free -h
test "$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)" -ge 6291456
test -z "$(ss -ltnH "sport = :$PORT")"
test -z "$(pgrep -u "$(id -un)" -f "$ACE_DIR/qemu/bin/qemu-system-riscv64")"
stop_if_failed "step 3"

section "4. Check that the images are the ones reviewed in G12"
FW="$ACE_DIR/security-monitor/opensbi/platform/generic/firmware/fw_payload.elf"
HV="$ACE_DIR/hypervisor/buildroot/images/rootfs.ext2"
PRISTINE="$PROJECT_ROOT/build/pristine/hypervisor-rootfs.ext2"
test "$(sha256sum < "$FW" | cut -d' ' -f1)" = 6a41b58184c3f25db92b036635abf9738df2a4b375e63c58100e313473b8c286
test "$(sha256sum < "$PRISTINE" | cut -d' ' -f1)" = cc07c2dc1d60a3c38bbacfa2a7d7e5f64cccf41d55e625027875b0242a2ceeed
test "$(sha256sum < "$HV" | cut -d' ' -f1)" = cc07c2dc1d60a3c38bbacfa2a7d7e5f64cccf41d55e625027875b0242a2ceeed
stop_if_failed "step 4"

section "5. Create the TAP with a wrong PCR 4, exactly as upstream otherwise"
NEG="$PROJECT_ROOT/build/g15b"
rm -rf "$NEG"
mkdir -p "$NEG"
RIGHT=0x4e73d007ac0f79c9e476f42ead1ad1299cffc44ddd0719c690b368e22040da33
WRONG=0x4e73d007ac0f79c9e476f42ead1ad1299cffc44ddd0719c690b368e22040da34
test "$("$ACE_DIR/tools/cove-tap-tool" measure --base-address=0x80000000 --kernel-file="$ACE_DIR/confidential_vms/linux_vm/buildroot/images/Image" | cut -d' ' -f2-)" = "$RIGHT"
"$ACE_DIR/tools/cove-tap-tool" generate --pcrs 4="$WRONG" --secrets 0=0xc0ffeec0ffeec0ffeec0ffee --output-file="$NEG/cove_tap_qemu_wrong_pcr4"
ls -l "$NEG/cove_tap_qemu_wrong_pcr4"
sha256sum "$NEG/cove_tap_qemu_wrong_pcr4"
stop_if_failed "step 5"

section "6. Start the hypervisor and wait for its SSH"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
SERIAL="$PROJECT_ROOT/logs/G15b_hypervisor_serial_$STAMP.log"
cd "$ACE_DIR"
date -u
"$ACE_DIR/tools/ace" run --host-port="$PORT" < /dev/null > "$SERIAL" 2>&1 &
RUN_PID=$!
sleep 5
kill -0 "$RUN_PID"
stop_if_failed "step 6"
source "$ACE_DIR/tools/common.sh"
timeout 900 bash -c "source '$ACE_DIR/tools/common.sh'; wait_for_ssh root localhost $PORT" > /dev/null 2>&1
date -u
$SSH_CMD -p "$PORT" root@localhost whoami

section "7. Put the wrong TAP in place and keep the original"
$SSH_CMD -p "$PORT" root@localhost 'cat > /root/cove_tap_qemu_wrong_pcr4' < "$NEG/cove_tap_qemu_wrong_pcr4"
$SSH_CMD -p "$PORT" root@localhost 'cp /root/linux_vm/cove_tap_qemu /root/cove_tap_qemu.orig && cp /root/cove_tap_qemu_wrong_pcr4 /root/linux_vm/cove_tap_qemu && sha256sum /root/cove_tap_qemu.orig /root/linux_vm/cove_tap_qemu'
test "$($SSH_CMD -p "$PORT" root@localhost 'sha256sum /root/linux_vm/cove_tap_qemu' | cut -d' ' -f1)" = "$(sha256sum < "$NEG/cove_tap_qemu_wrong_pcr4" | cut -d' ' -f1)"

section "8. Negative run: start the confidential VM with the wrong TAP and request the secret"
N0=$(wc -l < "$SERIAL")
$SSH_CMD -p "$PORT" root@localhost 'cd /root && nohup ./run_linux_vm_qemu.sh -s=1 -m=256M --host-port=2222 < /dev/null > /root/tvm_console_negative.log 2>&1 & sleep 5; head -n 8 /root/tvm_console_negative.log; ps | grep "[q]emu-system-riscv64" || echo "(no confidential VM process)"'
timeout 200 $SSH_CMD -p "$PORT" root@localhost '. /root/common.sh; for i in $(seq 1 60); do [ "$($SSH_CMD -p2222 root@localhost whoami)" = root ] && break; sleep 2; done; $SSH_CMD -p2222 root@localhost whoami' || echo "(the confidential VM did not answer)"
$SSH_CMD -p "$PORT" root@localhost '. /root/common.sh; $SSH_CMD -p2222 root@localhost "insmod /root/ace_module/ace.ko; dmesg | tail -n 12"' || echo "(the confidential VM is not reachable)"
NEG_COUNT="$($SSH_CMD -p "$PORT" root@localhost '. /root/common.sh; $SSH_CMD -p2222 root@localhost "dmesg | grep -c Secret=0xc0ffeec0ffeec0ffeec0ffee; true" || true')"
echo "negative run: secret lines in the VM = ${NEG_COUNT:-none (the VM was not reachable)}"
N1=$(wc -l < "$SERIAL")
sed -n "$((N0 + 1)),${N1}p" "$SERIAL" | grep -E '#ACE|PCR4=' || echo "(no security monitor output in this run)"
$SSH_CMD -p "$PORT" root@localhost 'cat /root/tvm_console_negative.log' > "$PROJECT_ROOT/logs/G15b_tvm_console_negative_$STAMP.log"
$SSH_CMD -p "$PORT" root@localhost '. /root/common.sh; kill_confidential_vm; sleep 2; ps | grep "[q]emu-system-riscv64" || echo "(no confidential VM running)"'

section "9. Restore the original TAP and check it byte for byte"
$SSH_CMD -p "$PORT" root@localhost 'cp /root/cove_tap_qemu.orig /root/linux_vm/cove_tap_qemu && cmp /root/cove_tap_qemu.orig /root/linux_vm/cove_tap_qemu && sha256sum /root/linux_vm/cove_tap_qemu'
test "$($SSH_CMD -p "$PORT" root@localhost 'sha256sum /root/linux_vm/cove_tap_qemu' | cut -d' ' -f1)" = 1c28e8990d987de81490dba30885f84a59a60217aee60adc769454dc6cc8ed9d

section "10. Positive run: start the confidential VM with the original TAP and request the secret"
N2=$(wc -l < "$SERIAL")
$SSH_CMD -p "$PORT" root@localhost 'cd /root && nohup ./run_linux_vm_qemu.sh -s=1 -m=256M --host-port=2222 < /dev/null > /root/tvm_console_positive.log 2>&1 & sleep 5; head -n 8 /root/tvm_console_positive.log; ps | grep "[q]emu-system-riscv64" || echo "(no confidential VM process)"'
timeout 400 $SSH_CMD -p "$PORT" root@localhost '. /root/common.sh; for i in $(seq 1 150); do [ "$($SSH_CMD -p2222 root@localhost whoami)" = root ] && break; sleep 2; done; $SSH_CMD -p2222 root@localhost whoami'
$SSH_CMD -p "$PORT" root@localhost '. /root/common.sh; $SSH_CMD -p2222 root@localhost "insmod /root/ace_module/ace.ko; dmesg | tail -n 12"'
POS_COUNT="$($SSH_CMD -p "$PORT" root@localhost '. /root/common.sh; $SSH_CMD -p2222 root@localhost "dmesg | grep -c Secret=0xc0ffeec0ffeec0ffeec0ffee; true" || true')"
echo "positive run: secret lines in the VM = ${POS_COUNT:-none (the VM was not reachable)}"
N3=$(wc -l < "$SERIAL")
sed -n "$((N2 + 1)),${N3}p" "$SERIAL" | grep -E '#ACE|PCR4=' || echo "(no security monitor output in this run)"
$SSH_CMD -p "$PORT" root@localhost 'cat /root/tvm_console_positive.log' > "$PROJECT_ROOT/logs/G15b_tvm_console_positive_$STAMP.log"
$SSH_CMD -p "$PORT" root@localhost '. /root/common.sh; kill_confidential_vm; sleep 2; ps | grep "[q]emu-system-riscv64" || echo "(no confidential VM running)"'

section "11. Judge the controlled experiment"
echo "negative run (PCR 4 = $WRONG): secret lines = ${NEG_COUNT:-none}"
echo "positive run (PCR 4 = $RIGHT): secret lines = ${POS_COUNT:-none}"
test "${NEG_COUNT:-0}" -eq 0
test "$(sed -n "$((N0 + 1)),${N1}p" "$SERIAL" | grep -c 'Attestation succeeded')" -eq 0
test "${POS_COUNT:-0}" -eq 1
test "$(sed -n "$((N2 + 1)),${N3}p" "$SERIAL" | grep -c 'Attestation succeeded')" -eq 1

section "12. Shut down the hypervisor and stop only the QEMU started here"
$SSH_CMD -p "$PORT" root@localhost poweroff || echo "(the connection closed during poweroff)"
timeout 300 tail --pid="$RUN_PID" -f /dev/null || echo "(the run script was still running after 300 s)"
pkill -u "$(id -un)" -f "hostfwd=tcp:127.0.0.1:$PORT-:22" || echo "(no QEMU of this gate left to stop)"
wait "$RUN_PID" && echo "run script exited with status 0" || echo "run script exited with status $?"
date -u
test -z "$(pgrep -u "$(id -un)" -f "$ACE_DIR/qemu/bin/qemu-system-riscv64")"
test -z "$(ss -ltnH "sport = :$PORT")"

section "13. Seal the console logs, restore the disk image, and check the project"
chmod 400 "$SERIAL" "$PROJECT_ROOT/logs/G15b_tvm_console_negative_$STAMP.log" "$PROJECT_ROOT/logs/G15b_tvm_console_positive_$STAMP.log"
sha256sum "$SERIAL" "$PROJECT_ROOT/logs/G15b_tvm_console_negative_$STAMP.log" "$PROJECT_ROOT/logs/G15b_tvm_console_positive_$STAMP.log"
sha256sum "$HV"
cp "$PRISTINE" "$HV"
test "$(sha256sum < "$HV" | cut -d' ' -f1)" = cc07c2dc1d60a3c38bbacfa2a7d7e5f64cccf41d55e625027875b0242a2ceeed
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
git status --short
cd "$PROJECT_ROOT"
git status --short
free -h


# ---------------- Logging harness: finish (not part of the procedure) -------
finish "completed"
