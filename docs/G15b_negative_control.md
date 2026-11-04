# G15b: Negative Control of the Local Attestation

G14 and G15 showed that the security monitor releases the demo secret when the confidential VM's measurement matches the reference
value in its TAP. This gate shows the other half: when the reference value does not match, the secret is **not** released. It is a
controlled experiment in one boot of the hypervisor, in which the confidential VM is started twice and only the TAP differs.

Previous gate: **G15 PASS** (see `logs/review/G15_review.md`). This gate was added at the owner's decision after checkpoint 3.

The same commands are run, with logging, by [`scripts/G15b_negative_control.sh`](../scripts/G15b_negative_control.sh).

## Design

| | Negative run | Positive run |
|---|---|---|
| TAP | generated exactly as upstream (`confidential-vms/linux_vm/Makefile:83`), but `--pcrs 4=...da34` | the original TAP of G12 (`1c28e899...`), restored and checked byte for byte |
| PCR 4 in the TAP | `0x4e73d007ac0f79c9e476f42ead1ad1299cffc44ddd0719c690b368e22040da34` (last hex digit changed) | `0x4e73d007ac0f79c9e476f42ead1ad1299cffc44ddd0719c690b368e22040da33` (the VM kernel's measurement) |
| Secret in the TAP | `0=0xc0ffeec0ffeec0ffeec0ffee` | `0=0xc0ffeec0ffeec0ffeec0ffee` |
| Everything else | same hypervisor boot, same VM kernel and disk, same upstream `run_linux_vm_qemu.sh -s=1 -m=256M`, same `insmod ace.ko` | same |
| Expected | no `Secret=...` line in the VM; no `Attestation succeeded` from the security monitor | exactly one `Secret=...` line; exactly one `Attestation succeeded` |

The security monitor may react to the wrong reference in one of two ways: refuse to create the confidential VM, or create it and
not release the secret. Both mean that the secret was not released, and the criteria above accept both; the review records which
one happened. The security monitor's output of each run is separated by the line count of the serial console before and after it.

**Scope.** One wrong value, differing in 4 bits from the correct one, is tested. This shows that the release of the secret depends on
the measurement; it is not a test of the strength of the cryptography or of attacks against the TAP.

Set the paths first:

```bash
PROJECT_ROOT=~/projects/IBM-ACE-On-QEMU-Reproduction
DOWNLOAD_DIR=~/download
```

## 1. Verify the downloaded files and all sealed evidence

```bash
cd "$DOWNLOAD_DIR"
sha256sum G15b_negative_control.sh G15b_negative_control.md
echo "329eefff908d59b7ff74c887c48a04a9c725de10ebc0c6e4cf9063f420298d8c  G15_review.md" | sha256sum -c -
cd "$PROJECT_ROOT/logs"
sha256sum -c *.sha256
```

Expected: every line ends with `OK`. If any check fails, stop.

## 2. Commit the reviewed G15 work (local only, UTC)

```bash
cd "$PROJECT_ROOT"
cp "$DOWNLOAD_DIR/G15_review.md" logs/review/
git add scripts/G15_regression_test.sh docs/G15_regression_test.md
git status --short
git diff --cached --quiet || TZ=UTC0 git commit -m "G15: upstream regression test (ace test), unchanged"
git log -1 --format='%h  %aI  %an <%ae>  %s'
git show --stat --format= HEAD
cp "$DOWNLOAD_DIR/G15b_negative_control.sh" scripts/
cp "$DOWNLOAD_DIR/G15b_negative_control.md" docs/
```

## 3. Check the host before booting: memory, port, other ACE QEMU

```bash
source "$PROJECT_ROOT/scripts/build_env.sh"
PORT=4022
uname -r
free -h
test "$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)" -ge 6291456
test -z "$(ss -ltnH "sport = :$PORT")"
test -z "$(pgrep -u "$(id -un)" -f "$ACE_DIR/qemu/bin/qemu-system-riscv64")"
```

## 4. Check that the images are the ones reviewed in G12

```bash
FW="$ACE_DIR/security-monitor/opensbi/platform/generic/firmware/fw_payload.elf"
HV="$ACE_DIR/hypervisor/buildroot/images/rootfs.ext2"
PRISTINE="$PROJECT_ROOT/build/pristine/hypervisor-rootfs.ext2"
test "$(sha256sum < "$FW" | cut -d' ' -f1)" = 6a41b58184c3f25db92b036635abf9738df2a4b375e63c58100e313473b8c286
test "$(sha256sum < "$PRISTINE" | cut -d' ' -f1)" = cc07c2dc1d60a3c38bbacfa2a7d7e5f64cccf41d55e625027875b0242a2ceeed
test "$(sha256sum < "$HV" | cut -d' ' -f1)" = cc07c2dc1d60a3c38bbacfa2a7d7e5f64cccf41d55e625027875b0242a2ceeed
```

## 5. Create the TAP with a wrong PCR 4, exactly as upstream otherwise

```bash
NEG="$PROJECT_ROOT/build/g15b"
rm -rf "$NEG"
mkdir -p "$NEG"
RIGHT=0x4e73d007ac0f79c9e476f42ead1ad1299cffc44ddd0719c690b368e22040da33
WRONG=0x4e73d007ac0f79c9e476f42ead1ad1299cffc44ddd0719c690b368e22040da34
test "$("$ACE_DIR/tools/cove-tap-tool" measure --base-address=0x80000000 --kernel-file="$ACE_DIR/confidential_vms/linux_vm/buildroot/images/Image" | cut -d' ' -f2-)" = "$RIGHT"
"$ACE_DIR/tools/cove-tap-tool" generate --pcrs 4="$WRONG" --secrets 0=0xc0ffeec0ffeec0ffeec0ffee --output-file="$NEG/cove_tap_qemu_wrong_pcr4"
ls -l "$NEG/cove_tap_qemu_wrong_pcr4"
sha256sum "$NEG/cove_tap_qemu_wrong_pcr4"
```

The `test` line confirms that the VM kernel still measures to the correct value, so the only wrong input in the negative run is the
reference in the TAP. The `generate` line is the upstream command with the TAP tool of G07, differing only in the PCR 4 value.

## 6. Start the hypervisor and wait for its SSH

```bash
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
SERIAL="$PROJECT_ROOT/logs/G15b_hypervisor_serial_$STAMP.log"
cd "$ACE_DIR"
date -u
"$ACE_DIR/tools/ace" run --host-port="$PORT" < /dev/null > "$SERIAL" 2>&1 &
RUN_PID=$!
sleep 5
kill -0 "$RUN_PID"
source "$ACE_DIR/tools/common.sh"
timeout 900 bash -c "source '$ACE_DIR/tools/common.sh'; wait_for_ssh root localhost $PORT" > /dev/null 2>&1
date -u
$SSH_CMD -p "$PORT" root@localhost whoami
```

As in G13 and G14. If the run script has exited after 5 s, QEMU did not start and the gate stops.

## 7. Put the wrong TAP in place and keep the original

```bash
$SSH_CMD -p "$PORT" root@localhost 'cat > /root/cove_tap_qemu_wrong_pcr4' < "$NEG/cove_tap_qemu_wrong_pcr4"
$SSH_CMD -p "$PORT" root@localhost 'cp /root/linux_vm/cove_tap_qemu /root/cove_tap_qemu.orig && cp /root/cove_tap_qemu_wrong_pcr4 /root/linux_vm/cove_tap_qemu && sha256sum /root/cove_tap_qemu.orig /root/linux_vm/cove_tap_qemu'
test "$($SSH_CMD -p "$PORT" root@localhost 'sha256sum /root/linux_vm/cove_tap_qemu' | cut -d' ' -f1)" = "$(sha256sum < "$NEG/cove_tap_qemu_wrong_pcr4" | cut -d' ' -f1)"
```

The wrong TAP is copied into the hypervisor over SSH and put at the path that the upstream run script uses
(`/root/linux_vm/cove_tap_qemu`); the original is kept as `/root/cove_tap_qemu.orig`. The last line checks that the file in place is
exactly the one created in step 5. Only the running hypervisor's disk is changed; it is restored from the pristine copy in step 13.

## 8. Negative run: start the confidential VM with the wrong TAP and request the secret

```bash
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
```

The same steps as G14, with the wrong TAP. If the security monitor refuses the VM, it never answers on SSH; the wait is therefore
shorter (2 minutes), and every command that needs the VM records its absence instead of failing. `N0` and `N1` delimit the security
monitor's output for this run.

## 9. Restore the original TAP and check it byte for byte

```bash
$SSH_CMD -p "$PORT" root@localhost 'cp /root/cove_tap_qemu.orig /root/linux_vm/cove_tap_qemu && cmp /root/cove_tap_qemu.orig /root/linux_vm/cove_tap_qemu && sha256sum /root/linux_vm/cove_tap_qemu'
test "$($SSH_CMD -p "$PORT" root@localhost 'sha256sum /root/linux_vm/cove_tap_qemu' | cut -d' ' -f1)" = 1c28e8990d987de81490dba30885f84a59a60217aee60adc769454dc6cc8ed9d
```

The TAP in place must again be exactly the one carried by the G12 image (G12 review F2), so the positive run repeats G14's conditions.

## 10. Positive run: start the confidential VM with the original TAP and request the secret

```bash
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
```

The same steps with the original TAP, in the same hypervisor boot. `N2` and `N3` delimit the security monitor's output for this run.

## 11. Judge the controlled experiment

```bash
echo "negative run (PCR 4 = $WRONG): secret lines = ${NEG_COUNT:-none}"
echo "positive run (PCR 4 = $RIGHT): secret lines = ${POS_COUNT:-none}"
test "${NEG_COUNT:-0}" -eq 0
test "$(sed -n "$((N0 + 1)),${N1}p" "$SERIAL" | grep -c 'Attestation succeeded')" -eq 0
test "${POS_COUNT:-0}" -eq 1
test "$(sed -n "$((N2 + 1)),${N3}p" "$SERIAL" | grep -c 'Attestation succeeded')" -eq 1
```

All four lines must hold: in the negative run neither the VM nor the security monitor shows a successful attestation, and in the
positive run both do, exactly once. A VM that was not reachable in the negative run counts as 0 secret lines.

## 12. Shut down the hypervisor and stop only the QEMU started here

```bash
$SSH_CMD -p "$PORT" root@localhost poweroff || echo "(the connection closed during poweroff)"
timeout 300 tail --pid="$RUN_PID" -f /dev/null || echo "(the run script was still running after 300 s)"
pkill -u "$(id -un)" -f "hostfwd=tcp:127.0.0.1:$PORT-:22" || echo "(no QEMU of this gate left to stop)"
wait "$RUN_PID" && echo "run script exited with status 0" || echo "run script exited with status $?"
date -u
test -z "$(pgrep -u "$(id -un)" -f "$ACE_DIR/qemu/bin/qemu-system-riscv64")"
test -z "$(ss -ltnH "sport = :$PORT")"
```

## 13. Seal the console logs, restore the disk image, and check the project

```bash
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
```

The disk restore also removes the wrong TAP and the original's backup from the hypervisor's file system.

## 14. Run all steps with logging

```bash
bash scripts/G15b_negative_control.sh
```

On the first run, use the downloaded copy: `bash ~/download/G15b_negative_control.sh`.
The script stops after step 1 to 5 if a check failed, and in step 6 if QEMU did not start. Once QEMU runs, it does not stop early;
every check is recorded, and steps 12 and 13 always run. If the script is interrupted after step 6, stop the emulated machine with
`pkill -u "$(id -un)" -f "hostfwd=tcp:127.0.0.1:4022-:22"`.
