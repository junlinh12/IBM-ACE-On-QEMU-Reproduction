# G14: Confidential VM, Local Attestation, and the Demo Secret

This gate runs the central experiment of ACE. On the emulated platform booted as in G13, the untrusted Linux hypervisor starts a
confidential VM (TVM) with KVM and the CoVE extensions; the ACE security monitor creates the TVM in confidential memory and
measures it. Inside the VM, the kernel module `ace.ko` requests the local attestation; the security monitor compares the VM's
measurement with the reference value in the TVM attestation payload (TAP) and, if they match, releases the secret stored in
the TAP. The gate records the VM (success criterion E5), the attestation (E6), and the released secret (E7).

Previous gate: **G13 PASS** (see `logs/review/G13_review.md`).

The same commands are run, with logging, by [`scripts/G14_attestation.sh`](../scripts/G14_attestation.sh).

| Item | Value | Source |
|---|---|---|
| VM start | `/root/run_linux_vm_qemu.sh -s=1 -m=256M` inside the hypervisor: nested QEMU 8.1.1 (with `cove.patch`) with `--enable-kvm -machine virt,cove=true,cove-tap-filename=/root/linux_vm/cove_tap_qemu` | `confidential-vms/linux_vm/hypervisor_rootfs/run_linux_vm_qemu.sh:63-74` |
| VM disk and kernel | `/root/linux_vm/rootfs.ext2` (with `ace.ko`, G12) and `/root/linux_vm/Image` (`d10c9b01...`) | G12 review |
| Reference measurement | PCR 4 `0x4e73d007ac0f79c9e476f42ead1ad1299cffc44ddd0719c690b368e22040da33` in `cove_tap_qemu` | G11, G12 reviews |
| Demo secret | `0xc0ffeec0ffeec0ffeec0ffee`, secret 0 of the TAP | `confidential-vms/linux_vm/Makefile:83` (SAFETY_AUDIT A15) |
| Pass criterion for E7 | `dmesg` of the VM contains `Secret=0xc0ffeec0ffeec0ffeec0ffee` exactly once after `insmod ace.ko` | `hypervisor/rootfs/test_attestation.sh:17-25` |

## How this gate relates to the upstream attestation test

Steps 7-10 follow `hypervisor/rootfs/test_attestation.sh` command by command: start the VM with `-s=1 -m=256M`, wait for its
SSH, `insmod /root/ace_module/ace.ko`, and count `Secret=0xc0ffeec0ffeec0ffeec0ffee` in `dmesg`, which must be exactly 1. Three
things differ, to obtain evidence:

| Upstream test | This gate | Why |
|---|---|---|
| `--daemonize`, random port | console written to `/root/tvm_console.log`, port 2222 | the VM's boot console is evidence for E5; `--daemonize` discards it |
| waits 30 x 1 s for the VM's SSH | waits up to 150 x 2 s | nested emulation can be slower (G05b review F4) |
| only the count | also records the VM's kernel log, the module's output, and the security monitor's console | E5 and E6 need more than the final count |

The unchanged upstream test is run in G15.

Set the paths first:

```bash
PROJECT_ROOT=~/projects/IBM-ACE-On-QEMU-Reproduction
DOWNLOAD_DIR=~/download
```

## 1. Verify the downloaded files and all sealed evidence

```bash
cd "$DOWNLOAD_DIR"
sha256sum G14_attestation.sh G14_attestation.md
echo "5f5c5e4ace09cab0399d9d21d317dc412116510710d3f946ff09e864a220f932  G13_review.md" | sha256sum -c -
cd "$PROJECT_ROOT/logs"
sha256sum -c *.sha256
```

Expected: every line ends with `OK`. If any check fails, stop.

## 2. Commit the reviewed G13 work (local only, UTC)

```bash
cd "$PROJECT_ROOT"
cp "$DOWNLOAD_DIR/G13_review.md" logs/review/
git add scripts/G13_boot_hypervisor.sh docs/G13_boot_hypervisor.md
git status --short
git diff --cached --quiet || TZ=UTC0 git commit -m "G13: boot OpenSBI, the ACE security monitor, and the Linux hypervisor"
git log -1 --format='%h  %aI  %an <%ae>  %s'
git show --stat --format= HEAD
cp "$DOWNLOAD_DIR/G14_attestation.sh" scripts/
cp "$DOWNLOAD_DIR/G14_attestation.md" docs/
```

## 3. Check the host before booting: memory, port, other ACE QEMU

```bash
source "$PROJECT_ROOT/scripts/build_env.sh"
PORT=4022
uname -r
free -h
test "$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)" -ge 6291456
ss -ltnH "sport = :$PORT"
test -z "$(ss -ltnH "sport = :$PORT")"
test -z "$(pgrep -u "$(id -un)" -f "$ACE_DIR/qemu/bin/qemu-system-riscv64")"
```

As in G13: at least 6 GiB available, port 4022 free, no QEMU of this project running.

## 4. Check that the images are the ones reviewed in G12

```bash
FW="$ACE_DIR/security-monitor/opensbi/platform/generic/firmware/fw_payload.elf"
HV="$ACE_DIR/hypervisor/buildroot/images/rootfs.ext2"
PRISTINE="$PROJECT_ROOT/build/pristine/hypervisor-rootfs.ext2"
test "$(sha256sum < "$FW" | cut -d' ' -f1)" = 6a41b58184c3f25db92b036635abf9738df2a4b375e63c58100e313473b8c286
test "$(sha256sum < "$PRISTINE" | cut -d' ' -f1)" = cc07c2dc1d60a3c38bbacfa2a7d7e5f64cccf41d55e625027875b0242a2ceeed
test "$(sha256sum < "$HV" | cut -d' ' -f1)" = cc07c2dc1d60a3c38bbacfa2a7d7e5f64cccf41d55e625027875b0242a2ceeed
```

G13 restored the disk from the pristine copy, so the image to boot must again be exactly the G12 image.

## 5. Start the hypervisor with the upstream run script

```bash
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
pgrep -a -u "$(id -un)" -f "hostfwd=tcp:127.0.0.1:$PORT-:22" | cut -c1-400
ss -ltnH "sport = :$PORT"
```

As in G13. Two console logs are kept in `logs/`: the platform's serial console (OpenSBI, the security monitor, the hypervisor) and,
from step 11, the confidential VM's console.

## 6. Wait for the hypervisor's SSH (at most 15 minutes)

```bash
source "$ACE_DIR/tools/common.sh"
timeout 900 bash -c "source '$ACE_DIR/tools/common.sh'; wait_for_ssh root localhost $PORT" > /dev/null 2>&1
date -u
$SSH_CMD -p "$PORT" root@localhost whoami
```

## 7. Start the confidential VM inside the hypervisor

```bash
$SSH_CMD -p "$PORT" root@localhost 'cd /root && nohup ./run_linux_vm_qemu.sh -s=1 -m=256M --host-port=2222 < /dev/null > /root/tvm_console.log 2>&1 & sleep 5; head -n 5 /root/tvm_console.log; ps | grep "[q]emu-system-riscv64"'
date -u
```

The command runs inside the hypervisor. It starts the upstream VM script with the upstream test's size (1 vCPU, 256 MiB), keeps
the VM's console in `/root/tvm_console.log`, and then shows the first lines of that console and the nested QEMU process.
`nohup` keeps the VM running after this SSH session ends.

## 8. Wait for the confidential VM's SSH (at most 5 minutes)

```bash
timeout 400 $SSH_CMD -p "$PORT" root@localhost '. /root/common.sh; for i in $(seq 1 150); do [ "$($SSH_CMD -p2222 root@localhost whoami)" = root ] && break; sleep 2; done; $SSH_CMD -p2222 root@localhost whoami'
date -u
```

Inside the hypervisor, `/root/common.sh` (the upstream test helper) defines `SSH_CMD` for logging in to the VM as `root`. The loop
is the upstream `wait_for_ssh` with a longer limit. The command must end by printing `root`.

## 9. Record the confidential VM (E5)

```bash
$SSH_CMD -p "$PORT" root@localhost '. /root/common.sh; $SSH_CMD -p2222 root@localhost "uname -a; grep -c ^processor /proc/cpuinfo; free -m; cat /root/this_is_confidential_vm_filesystem"'
$SSH_CMD -p "$PORT" root@localhost '. /root/common.sh; $SSH_CMD -p2222 root@localhost "dmesg | grep -i -E \"cove|confidential|sbi|swiotlb|Machine model|Linux version\" || echo \"(no matching line)\""'
```

Commands inside the VM go through two SSH hops: from the host to the hypervisor (port 4022), and from the hypervisor to the VM
(port 2222). E5 needs: the VM's own kernel running with 1 vCPU and about 256 MiB; the marker file of the confidential VM's file
system; and the kernel's messages about running as a CoVE guest (confidential computing, bounce buffers through `swiotlb` for
virtio I/O).

## 10. Run the local attestation and read the secret (E6, E7)

```bash
$SSH_CMD -p "$PORT" root@localhost '. /root/common.sh; $SSH_CMD -p2222 root@localhost "insmod /root/ace_module/ace.ko"'
$SSH_CMD -p "$PORT" root@localhost '. /root/common.sh; $SSH_CMD -p2222 root@localhost "dmesg | tail -n 30"'
$SSH_CMD -p "$PORT" root@localhost '. /root/common.sh; $SSH_CMD -p2222 root@localhost "dmesg | grep Secret"'
test "$($SSH_CMD -p "$PORT" root@localhost '. /root/common.sh; $SSH_CMD -p2222 root@localhost "dmesg | grep -c Secret=0xc0ffeec0ffeec0ffeec0ffee"')" = 1
```

`insmod` is the upstream test's attestation request. The last line is the upstream pass criterion: the secret line appears
exactly once in the VM's kernel log. It fails otherwise, and the failure is recorded.

## 11. Record what the security monitor and the VM reported

```bash
grep -n -m 200 -E 'TVM|tvm|[Aa]ttest|[Mm]easure|PCR|pcr|[Dd]igest|TAP|[Ss]ecret|[Pp]romot|0x4e73d007' "$SERIAL" || echo "(no matching line)"
$SSH_CMD -p "$PORT" root@localhost 'cat /root/tvm_console.log' > "$TVM_CONSOLE"
wc -l "$TVM_CONSOLE"
head -n 120 "$TVM_CONSOLE"
grep -n -i -E 'secret|attest|cove|ace' "$TVM_CONSOLE" || echo "(no matching line)"
```

The security monitor, built with `--features verbose` (G10), reports on the platform console how it creates, measures, and
attests the TVM. Matching its output with the TAP's PCR 4 (`0x4e73d007...`) is the evidence for E6. The VM's console is copied
into `logs/`. These lines only record information: if nothing matches, they print `(no matching line)` instead of failing,
because the strict check of the attestation is the one in step 10.

## 12. Stop the confidential VM, then shut down the hypervisor

```bash
$SSH_CMD -p "$PORT" root@localhost '. /root/common.sh; kill_confidential_vm; sleep 2; ps | grep "[q]emu-system-riscv64" || echo "(no confidential VM running)"'
$SSH_CMD -p "$PORT" root@localhost poweroff || echo "(the connection closed during poweroff)"
timeout 300 tail --pid="$RUN_PID" -f /dev/null || echo "(the run script was still running after 300 s)"
pkill -u "$(id -un)" -f "hostfwd=tcp:127.0.0.1:$PORT-:22" || echo "(no QEMU of this gate left to stop)"
wait "$RUN_PID" && echo "run script exited with status 0" || echo "run script exited with status $?"
date -u
test -z "$(pgrep -u "$(id -un)" -f "$ACE_DIR/qemu/bin/qemu-system-riscv64")"
test -z "$(ss -ltnH "sport = :$PORT")"
```

`kill_confidential_vm` is the upstream test's way to end the VM; it runs inside the emulated hypervisor and can only affect the
nested QEMU there. The hypervisor is then shut down exactly as in G13.

## 13. Seal the console logs, restore the disk image, and check the project

```bash
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
```

Both console logs are made read-only and their SHA-256 are written into the sealed gate log. They stay private; the review log
contains masked excerpts.

## 14. Run all steps with logging

```bash
bash scripts/G14_attestation.sh
```

On the first run, use the downloaded copy: `bash ~/download/G14_attestation.sh`.
The script stops after step 1, 2, 3, or 4 if a check failed, and in step 5 if QEMU did not start. Once QEMU runs, it does not stop
early: every check is recorded, and steps 12 and 13 always run. If the script is interrupted after step 5, stop the emulated
machine with `pkill -u "$(id -un)" -f "hostfwd=tcp:127.0.0.1:4022-:22"`.
