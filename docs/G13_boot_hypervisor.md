# G13: Boot the Emulated RISC-V Platform (OpenSBI, ACE Security Monitor, Linux Hypervisor)

The first run gate. QEMU 8.2.1 (G08) emulates a RISC-V `virt` machine; it starts the firmware (G10: OpenSBI with the ACE security
monitor, carrying the hypervisor kernel of G09 as payload) with the hypervisor root file system (G12) as its disk. The gate records
the boot on the serial console (success criterion E3) and checks, over SSH, that KVM is available inside the emulated Linux (E4).
The confidential VM is started in G14.

Previous gate: **G12 PASS** (see `logs/review/G12_review.md`).

The same commands are run, with logging, by [`scripts/G13_boot_hypervisor.sh`](../scripts/G13_boot_hypervisor.sh).

| Item | Value | Source |
|---|---|---|
| Run script | `$ACE_DIR/tools/ace run` -> `ace_run_hypervisor.sh`, with patch 0002 (SSH forward on `127.0.0.1` only) | `tools/ace`, `tools/ace_run_hypervisor.sh` |
| Emulated machine | `-machine virt -cpu rv64 -bios none`, 4 vCPUs, 4 GiB, `-nographic` (serial console on standard output) | `tools/ace_run_hypervisor.sh:15-18,57-69` |
| Firmware | `fw_payload.elf`, SHA-256 `6a41b581...c286` (G10 = G12) | G12 review |
| Disk | `rootfs.ext4` -> `rootfs.ext2`, SHA-256 `cc07c2dc...eeed` (G12) | G12 review |
| SSH port | `4022` on `127.0.0.1` (`--host-port`), checked free before the boot | this gate |
| Login | `root` / `passwd`, through `SSH_CMD` of `tools/common.sh` (patch 0002: nothing written to `~/.ssh`) | `tools/common.sh:7-12` |

**Disk image.** QEMU opens the disk read-write, and the booted Linux may write to it. Step 4 keeps a pristine copy of the G12 image
in `build/pristine/`; step 10 records the image after the boot and then restores the pristine copy, so that every boot gate starts
from the reviewed image.

**If the gate is interrupted** after the boot (for example with Ctrl-C), the emulated machine keeps running in the background.
Stop exactly that QEMU with `pkill -u "$(id -un)" -f "hostfwd=tcp:127.0.0.1:4022-:22"`; never use `ace stop` (SAFETY_AUDIT A7).

Set the paths first:

```bash
PROJECT_ROOT=~/projects/IBM-ACE-On-QEMU-Reproduction
DOWNLOAD_DIR=~/download
```

## 1. Verify the downloaded files and all sealed evidence

```bash
cd "$DOWNLOAD_DIR"
sha256sum G13_boot_hypervisor.sh G13_boot_hypervisor.md
echo "934d0f0eeee4be33e2c53de2026dac9d334bc36d8a9f77d62e7406d3cebe033d  G12_review.md" | sha256sum -c -
cd "$PROJECT_ROOT/logs"
sha256sum -c *.sha256
```

Expected: every line ends with `OK`. If any check fails, stop.

## 2. Commit the reviewed G12 work (local only, UTC)

```bash
cd "$PROJECT_ROOT"
cp "$DOWNLOAD_DIR/G12_review.md" logs/review/
git add scripts/G12_rebuild_all.sh docs/G12_rebuild_all.md
git status --short
git diff --cached --quiet || TZ=UTC0 git commit -m "G12: integrated rebuild and end-to-end artifact audit"
git log -1 --format='%h  %aI  %an <%ae>  %s'
git show --stat --format= HEAD
cp "$DOWNLOAD_DIR/G13_boot_hypervisor.sh" scripts/
cp "$DOWNLOAD_DIR/G13_boot_hypervisor.md" docs/
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

The emulated machine has 4 GiB of memory, so at least 6 GiB (6291456 kB) must be available. Port 4022 must be free, and no QEMU
of this project may be running. Any of these failing stops the gate before anything is started.

## 4. Check that the images are the ones reviewed in G12, and keep a pristine copy

```bash
FW="$ACE_DIR/security-monitor/opensbi/platform/generic/firmware/fw_payload.elf"
HV="$ACE_DIR/hypervisor/buildroot/images/rootfs.ext2"
PRISTINE="$PROJECT_ROOT/build/pristine/hypervisor-rootfs.ext2"
test "$(sha256sum < "$FW" | cut -d' ' -f1)" = 6a41b58184c3f25db92b036635abf9738df2a4b375e63c58100e313473b8c286
test "$(sha256sum < "$HV" | cut -d' ' -f1)" = cc07c2dc1d60a3c38bbacfa2a7d7e5f64cccf41d55e625027875b0242a2ceeed
mkdir -p "$PROJECT_ROOT/build/pristine"
[ -f "$PRISTINE" ] || cp "$HV" "$PRISTINE"
test "$(sha256sum < "$PRISTINE" | cut -d' ' -f1)" = cc07c2dc1d60a3c38bbacfa2a7d7e5f64cccf41d55e625027875b0242a2ceeed
readlink "$ACE_DIR/hypervisor/buildroot/images/rootfs.ext4"
```

The gate boots only the reviewed firmware and disk. The pristine copy is made once and checked on every run.

## 5. Start the hypervisor with the upstream run script

```bash
SERIAL="$PROJECT_ROOT/logs/G13_hypervisor_serial_$(date -u +%Y%m%dT%H%M%SZ).log"
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

The run script is the upstream one, unchanged apart from patch 0002. With `-nographic`, the serial console (OpenSBI, the security
monitor, and the Linux console) is written to standard output, which is redirected to a file in `logs/` (One Project, One Log
System). `kill -0` checks that the run script is still running after 5 s; if it has already exited, QEMU did not start, nothing is
left running, and the gate stops here instead of waiting 15 minutes for SSH. The last two lines show the QEMU command line and that
the forwarded port listens on `127.0.0.1` only.

## 6. Wait for the hypervisor's SSH (at most 15 minutes)

```bash
source "$ACE_DIR/tools/common.sh"
timeout 900 bash -c "source '$ACE_DIR/tools/common.sh'; wait_for_ssh root localhost $PORT" > /dev/null 2>&1
date -u
$SSH_CMD -p "$PORT" root@localhost whoami
```

`wait_for_ssh` is the upstream helper; it has no time limit of its own (SAFETY_AUDIT A10), so it runs under `timeout 900`.
Its "waiting ..." lines are discarded; the two `date -u` lines measure the boot time. The last line must print `root`.

## 7. Record the platform boot from the serial console (E3)

```bash
wc -l "$SERIAL"
head -n 200 "$SERIAL"
grep -n -m 150 -E 'OpenSBI|Platform Name|Platform HART|Firmware Base|Firmware Size|Runtime SBI|Domain0|Boot HART|ACE|[Ss]ecurity [Mm]onitor|SBI specification|SBI implementation|Linux version|Machine model|riscv: ISA|kvm|COVE|CoVE' "$SERIAL"
```

E3 needs evidence of three stages on the serial console: OpenSBI's banner, the ACE security monitor's initialization (built with
`--features verbose`, G10), and the Linux hypervisor's boot. The output is bounded, because the security monitor's verbose output
can be long; the complete console stays in the serial log.

## 8. Check KVM inside the emulated Linux hypervisor (E4)

```bash
$SSH_CMD -p "$PORT" root@localhost 'uname -a'
$SSH_CMD -p "$PORT" root@localhost 'grep -c ^processor /proc/cpuinfo; grep -m 1 ^isa /proc/cpuinfo'
$SSH_CMD -p "$PORT" root@localhost 'ls -l /dev/kvm'
$SSH_CMD -p "$PORT" root@localhost 'dmesg | grep -i -E "kvm|cove|sbi"'
$SSH_CMD -p "$PORT" root@localhost 'free -m; ls -l /root /root/linux_vm'
```

| Check | Why |
|---|---|
| number of processors, `isa` line | 4 harts; the ISA string must contain the hypervisor extension (`h`) |
| `/dev/kvm` | the KVM device exists in the emulated Linux |
| `dmesg` | KVM initialized (for example "hypervisor extension available"), CoVE host support and the SBI implementation |
| `/root`, `/root/linux_vm` | the test scripts, kvmtool, and the confidential VM (G12) are present for G14 |

## 9. Shut down the hypervisor and stop only the QEMU started here

```bash
$SSH_CMD -p "$PORT" root@localhost poweroff || echo "(the connection closed during poweroff)"
timeout 300 tail --pid="$RUN_PID" -f /dev/null || echo "(the run script was still running after 300 s)"
pkill -u "$(id -un)" -f "hostfwd=tcp:127.0.0.1:$PORT-:22" || echo "(no QEMU of this gate left to stop)"
wait "$RUN_PID" && echo "run script exited with status 0" || echo "run script exited with status $?"
date -u
test -z "$(pgrep -u "$(id -un)" -f "$ACE_DIR/qemu/bin/qemu-system-riscv64")"
test -z "$(ss -ltnH "sport = :$PORT")"
```

`poweroff` inside the hypervisor ends QEMU through the firmware. If QEMU has not exited after 300 s, `pkill` stops only the process
whose command line contains this gate's forwarding rule; no other QEMU on the host can match it (SAFETY_AUDIT A7, A8). The last two
lines confirm that no QEMU of this project is left and that the port is free again.

## 10. Seal the serial log, restore the disk image, and check the project

```bash
chmod 400 "$SERIAL"
ls -l "$SERIAL"
sha256sum "$SERIAL"
tail -n 40 "$SERIAL"
sha256sum "$HV"
cp "$PRISTINE" "$HV"
test "$(sha256sum < "$HV" | cut -d' ' -f1)" = cc07c2dc1d60a3c38bbacfa2a7d7e5f64cccf41d55e625027875b0242a2ceeed
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
git status --short
cd "$PROJECT_ROOT"
git status --short
free -h
```

The serial log is made read-only and its SHA-256 is written into the gate log, which is itself sealed, so the serial log is sealed
too. It stays private: it contains the build banner of the kernels, which names the host. The hash of the disk after the boot shows
whether the guest wrote to it; the pristine copy is then restored.

## 11. Run all steps with logging

```bash
bash scripts/G13_boot_hypervisor.sh
```

On the first run, use the downloaded copy: `bash ~/download/G13_boot_hypervisor.sh`.
The script stops after step 1, 2, 3, or 4 if a check failed, before anything is started, and in step 5 if QEMU did not start. Once
QEMU runs, it does not stop early: every check is recorded, and the shutdown in step 9 and the restore in step 10 always run.
