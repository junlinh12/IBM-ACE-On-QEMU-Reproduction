#!/usr/bin/env bash
# =============================================================================
#  IBM-ACE-On-QEMU-Reproduction
#  G14 : Boot the confidential VM, run the local attestation, and retrieve the demo secret
#
#  Steps 1-13 below are plain Linux commands, identical to docs/G14_attestation.md.
#  Boots the hypervisor as in G13, then, inside it, starts the confidential VM with the upstream
#  run_linux_vm_qemu.sh (KVM, CoVE, TAP), loads ace.ko in the VM, and checks the secret exactly as
#  the upstream attestation test does. The VM's console is captured (the upstream test discards it).
#  Only the QEMU started here is ever stopped; the disk image is restored afterwards.
#  Stops before booting if less than 6 GiB of memory is available or the port is in use.
#  No sudo. Nothing is pushed. One local commit is made for the reviewed G13 work.
#
#  Before running, put these three files in ~/download:
#    G14_attestation.sh   G14_attestation.md   G13_review.md
#
#  Usage :  bash ~/download/G14_attestation.sh        (do not use sudo)
#  Upload:  logs/review/G14_*.review.log   (masked copy)
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

RAW="$(mktemp "$LOG_DIR/G14_$(date -u +%Y%m%dT%H%M%SZ)_XXXXXX.raw.log")" || exit 2
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

echo "# G14 Attestation | run=$RUN_ID | input_sha256=$(sha256sum "$LOG_DIR/$RUN_ID.input.sh" | cut -d' ' -f1)"
echo "# previous gate: G13 PASS (see logs/review/G13_review.md)"
printf 'G14 Attestation (%s)\n' "$RUN_ID" >&3
set -x
# ---------------- Logging harness: end ---------------------------------------


section "1. Verify the downloaded files and all sealed evidence"
cd "$DOWNLOAD_DIR"
sha256sum G14_attestation.sh G14_attestation.md
echo "5f5c5e4ace09cab0399d9d21d317dc412116510710d3f946ff09e864a220f932  G13_review.md" | sha256sum -c -
cd "$PROJECT_ROOT/logs"
sha256sum -c *.sha256
stop_if_failed "step 1"

section "2. Commit the reviewed G13 work (local only, UTC)"
cd "$PROJECT_ROOT"
cp "$DOWNLOAD_DIR/G13_review.md" logs/review/
git add scripts/G13_boot_hypervisor.sh docs/G13_boot_hypervisor.md
git status --short
git diff --cached --quiet || TZ=UTC0 git commit -m "G13: boot OpenSBI, the ACE security monitor, and the Linux hypervisor"
git log -1 --format='%h  %aI  %an <%ae>  %s'
git show --stat --format= HEAD
cp "$DOWNLOAD_DIR/G14_attestation.sh" scripts/
cp "$DOWNLOAD_DIR/G14_attestation.md" docs/
stop_if_failed "step 2"

section "3. Check the host before booting: memory, port, other ACE QEMU"
source "$PROJECT_ROOT/scripts/build_env.sh"
PORT=4022
uname -r
free -h
test "$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)" -ge 6291456
ss -ltnH "sport = :$PORT"
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

section "5. Start the hypervisor with the upstream run script"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
SERIAL="$PROJECT_ROOT/logs/G14_hypervisor_serial_$STAMP.log"
TVM_CONSOLE="$PROJECT_ROOT/logs/G14_tvm_console_$STAMP.log"
cd "$ACE_DIR"
date -u
"$ACE_DIR/tools/ace" run --host-port="$PORT" < /dev/null > "$SERIAL" 2>&1 &
RUN_PID=$!
echo "run script PID: $RUN_PID; serial console: $SERIAL"
sleep 5
kill -0 "$RUN_PID"
stop_if_failed "step 5"
pgrep -a -u "$(id -un)" -f "hostfwd=tcp:127.0.0.1:$PORT-:22" | cut -c1-400
ss -ltnH "sport = :$PORT"

section "6. Wait for the hypervisor's SSH (at most 15 minutes)"
source "$ACE_DIR/tools/common.sh"
timeout 900 bash -c "source '$ACE_DIR/tools/common.sh'; wait_for_ssh root localhost $PORT" > /dev/null 2>&1
date -u
$SSH_CMD -p "$PORT" root@localhost whoami

section "7. Start the confidential VM inside the hypervisor"
$SSH_CMD -p "$PORT" root@localhost 'cd /root && nohup ./run_linux_vm_qemu.sh -s=1 -m=256M --host-port=2222 < /dev/null > /root/tvm_console.log 2>&1 & sleep 5; head -n 5 /root/tvm_console.log; ps | grep "[q]emu-system-riscv64"'
date -u

section "8. Wait for the confidential VM's SSH (at most 5 minutes)"
timeout 400 $SSH_CMD -p "$PORT" root@localhost '. /root/common.sh; for i in $(seq 1 150); do [ "$($SSH_CMD -p2222 root@localhost whoami)" = root ] && break; sleep 2; done; $SSH_CMD -p2222 root@localhost whoami'
date -u

section "9. Record the confidential VM (E5)"
$SSH_CMD -p "$PORT" root@localhost '. /root/common.sh; $SSH_CMD -p2222 root@localhost "uname -a; grep -c ^processor /proc/cpuinfo; free -m; cat /root/this_is_confidential_vm_filesystem"'
$SSH_CMD -p "$PORT" root@localhost '. /root/common.sh; $SSH_CMD -p2222 root@localhost "dmesg | grep -i -E \"cove|confidential|sbi|swiotlb|Machine model|Linux version\" || echo \"(no matching line)\""'

section "10. Run the local attestation and read the secret (E6, E7)"
$SSH_CMD -p "$PORT" root@localhost '. /root/common.sh; $SSH_CMD -p2222 root@localhost "insmod /root/ace_module/ace.ko"'
$SSH_CMD -p "$PORT" root@localhost '. /root/common.sh; $SSH_CMD -p2222 root@localhost "dmesg | tail -n 30"'
$SSH_CMD -p "$PORT" root@localhost '. /root/common.sh; $SSH_CMD -p2222 root@localhost "dmesg | grep Secret"'
test "$($SSH_CMD -p "$PORT" root@localhost '. /root/common.sh; $SSH_CMD -p2222 root@localhost "dmesg | grep -c Secret=0xc0ffeec0ffeec0ffeec0ffee"')" = 1

section "11. Record what the security monitor and the VM reported"
grep -n -m 200 -E 'TVM|tvm|[Aa]ttest|[Mm]easure|PCR|pcr|[Dd]igest|TAP|[Ss]ecret|[Pp]romot|0x4e73d007' "$SERIAL" || echo "(no matching line)"
$SSH_CMD -p "$PORT" root@localhost 'cat /root/tvm_console.log' > "$TVM_CONSOLE"
wc -l "$TVM_CONSOLE"
head -n 120 "$TVM_CONSOLE"
grep -n -i -E 'secret|attest|cove|ace' "$TVM_CONSOLE" || echo "(no matching line)"

section "12. Stop the confidential VM, then shut down the hypervisor"
$SSH_CMD -p "$PORT" root@localhost '. /root/common.sh; kill_confidential_vm; sleep 2; ps | grep "[q]emu-system-riscv64" || echo "(no confidential VM running)"'
$SSH_CMD -p "$PORT" root@localhost poweroff || echo "(the connection closed during poweroff)"
timeout 300 tail --pid="$RUN_PID" -f /dev/null || echo "(the run script was still running after 300 s)"
pkill -u "$(id -un)" -f "hostfwd=tcp:127.0.0.1:$PORT-:22" || echo "(no QEMU of this gate left to stop)"
wait "$RUN_PID" && echo "run script exited with status 0" || echo "run script exited with status $?"
date -u
test -z "$(pgrep -u "$(id -un)" -f "$ACE_DIR/qemu/bin/qemu-system-riscv64")"
test -z "$(ss -ltnH "sport = :$PORT")"

section "13. Seal the console logs, restore the disk image, and check the project"
chmod 400 "$SERIAL" "$TVM_CONSOLE"
ls -l "$SERIAL" "$TVM_CONSOLE"
sha256sum "$SERIAL" "$TVM_CONSOLE"
tail -n 20 "$SERIAL"
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
