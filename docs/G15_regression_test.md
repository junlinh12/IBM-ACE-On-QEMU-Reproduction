# G15: Upstream Regression Test (`ace test`), Unchanged

The upstream CI ends with `ACE_DIR=$(pwd)/build/ PATH=$PATH:$(pwd)/build/tools ace test`. This gate runs the same test on the
reproduced system without changing it, and judges success criterion E8 from the test's result lines.

Previous gate: **G14 PASS** (see `logs/review/G14_review.md`). Checkpoint 3 was recorded after G14 (`logs/review/CHECKPOINT_3.md`).

The same commands are run, with logging, by [`scripts/G15_regression_test.sh`](../scripts/G15_regression_test.sh).

## What `ace test` does

| Step | Upstream file | Effect |
|---|---|---|
| start the hypervisor | `tools/ace_test.sh:15` -> `ace_run_hypervisor.sh --daemonize` | QEMU in the background, SSH forward on a random port 3000-5999 on `127.0.0.1` (patch 0002) |
| wait for SSH | `tools/ace_test.sh:22`, `tools/common.sh:15-20` | no time limit of its own (SAFETY_AUDIT A10) |
| run the tests | `tools/ace_test.sh:25` -> `/root/selftest.sh` in the hypervisor | `test_attestation` and `test_smp`; one line `<name>: success` or `<name>: failed` each, into `ace_test_results` |
| stop | `tools/ace_test.sh:28` -> `kill_qemu PORT` | `kill -9` of the QEMU with exactly this forwarding rule (patch 0002) |
| exit status | `tools/ace_test.sh:30-36` | 1 if a line contains `: failed`, else 0 (also 0 when there is no line) |

`test_attestation` starts the confidential VM, loads `ace.ko`, and requires `Secret=0xc0ffeec0ffeec0ffeec0ffee` exactly once (as G14
did step by step). `test_smp` starts the confidential VM with 2 vCPUs and reads the marker file of its file system.

**E8 rule (G05b review F2).** E8 is PASS only if the results contain exactly one `test_attestation: success`, exactly one
`test_smp: success`, and no `: failed`. The exit status alone is not enough, because the test exits 0 when no result line exists.

Set the paths first:

```bash
PROJECT_ROOT=~/projects/IBM-ACE-On-QEMU-Reproduction
DOWNLOAD_DIR=~/download
```

## 1. Verify the downloaded files and all sealed evidence

```bash
cd "$DOWNLOAD_DIR"
sha256sum G15_regression_test.sh G15_regression_test.md
echo "fc40d84ce26ff4c7478dd32df22c7ea9c64d7c64adcfbb1f43bbe8f00b86ed34  G14_review.md" | sha256sum -c -
echo "9cf6ea2c64924a6a2484e3d1afa2412e0cce140b9e591639762f939a970ea950  CHECKPOINT_3.md" | sha256sum -c -
cd "$PROJECT_ROOT/logs"
sha256sum -c *.sha256
```

Expected: every line ends with `OK`. If any check fails, stop.

## 2. Commit the reviewed G14 work (local only, UTC)

```bash
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
```

## 3. Check the host before the test: memory, other ACE QEMU, ports in the test's range

```bash
source "$PROJECT_ROOT/scripts/build_env.sh"
uname -r
free -h
test "$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)" -ge 6291456
test -z "$(pgrep -u "$(id -un)" -f "$ACE_DIR/qemu/bin/qemu-system-riscv64")"
ss -ltnH | awk '{print $4}' | sed 's/.*://' | sort -un | awk '$1 >= 3000 && $1 <= 5999'
```

The test picks its SSH port at random between 3000 and 5999; the last line lists the host ports in that range that are already in
use (for example <port>, G00). A collision would make QEMU fail to start; the 15-minute limit in step 5 then ends the test, and the
review would see it in `.run_tests.log`.

## 4. Check that the images are the ones reviewed in G12

```bash
FW="$ACE_DIR/security-monitor/opensbi/platform/generic/firmware/fw_payload.elf"
HV="$ACE_DIR/hypervisor/buildroot/images/rootfs.ext2"
PRISTINE="$PROJECT_ROOT/build/pristine/hypervisor-rootfs.ext2"
test "$(sha256sum < "$FW" | cut -d' ' -f1)" = 6a41b58184c3f25db92b036635abf9738df2a4b375e63c58100e313473b8c286
test "$(sha256sum < "$PRISTINE" | cut -d' ' -f1)" = cc07c2dc1d60a3c38bbacfa2a7d7e5f64cccf41d55e625027875b0242a2ceeed
test "$(sha256sum < "$HV" | cut -d' ' -f1)" = cc07c2dc1d60a3c38bbacfa2a7d7e5f64cccf41d55e625027875b0242a2ceeed
```

## 5. Run the upstream regression test, unchanged

```bash
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
TEST_DIR="$PROJECT_ROOT/build/g15-test"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"
date -u
timeout 900 "$ACE_DIR/tools/ace" test && echo "ace test exit status: 0" || echo "ace test exit status: $?"
date -u
```

`ace test` writes `.run_tests.log` and `ace_test_results` into the current directory, so it runs in an empty working directory under
`build/`. `timeout 900` bounds the upstream SSH wait, which has no limit of its own. The exit status is printed for the review;
the judgement is in step 6.

## 6. Judge the results by their lines (E8)

```bash
cat "$TEST_DIR/.run_tests.log"
cat "$TEST_DIR/ace_test_results"
test "$(grep -c '^test_attestation: success' "$TEST_DIR/ace_test_results")" = 1
test "$(grep -c '^test_smp: success' "$TEST_DIR/ace_test_results")" = 1
test "$(grep -c ': failed' "$TEST_DIR/ace_test_results")" = 0
```

Each `test` line fails, and is recorded as failed, if its condition does not hold. All three must hold for E8.

## 7. Check that no QEMU of this project is left

```bash
pgrep -a -u "$(id -un)" -f "$ACE_DIR/qemu/bin/qemu-system-riscv64" | cut -c1-300 || echo "(no QEMU of this project running)"
pkill -u "$(id -un)" -f "$ACE_DIR/qemu/bin/qemu-system-riscv64" || echo "(nothing to stop)"
sleep 2
test -z "$(pgrep -u "$(id -un)" -f "$ACE_DIR/qemu/bin/qemu-system-riscv64")"
```

`ace test` stops its QEMU itself. If the test was cut short (for example by the time limit), its QEMU may still run. Step 3 proved
that no QEMU of this project ran before the test, so a process running this project's QEMU binary can only be the test's own; other
projects' QEMU use other binaries and cannot match.

## 8. Read the test logs left on the hypervisor's disk

```bash
debugfs -R "ls -l /root" "$HV"
debugfs -R "cat /root/test_attestation.log" "$HV"
debugfs -R "cat /root/test_smp.log" "$HV"
debugfs -R "cat /root/tmp_dmesg.log" "$HV"
debugfs -R "cat /root/tmp_smp_dmesg.log" "$HV"
```

Inside the hypervisor, `selftest.sh` and the two tests write their logs to `/root`. The upstream test ends QEMU with `kill -9`, so
these files may not have reached the disk image; `debugfs` reads whatever was written, read-only. This step is best effort and only
records information.

## 9. Keep the results in logs/ and restore the disk image

```bash
cp "$TEST_DIR/ace_test_results" "$PROJECT_ROOT/logs/G15_ace_test_results_$STAMP.log"
cp "$TEST_DIR/.run_tests.log" "$PROJECT_ROOT/logs/G15_run_tests_$STAMP.log"
chmod 400 "$PROJECT_ROOT/logs/G15_ace_test_results_$STAMP.log" "$PROJECT_ROOT/logs/G15_run_tests_$STAMP.log"
sha256sum "$PROJECT_ROOT/logs/G15_ace_test_results_$STAMP.log" "$PROJECT_ROOT/logs/G15_run_tests_$STAMP.log"
sha256sum "$HV"
cp "$PRISTINE" "$HV"
test "$(sha256sum < "$HV" | cut -d' ' -f1)" = cc07c2dc1d60a3c38bbacfa2a7d7e5f64cccf41d55e625027875b0242a2ceeed
```

The two result files are copied into `logs/` (One Project, One Log System), made read-only, and sealed through this gate's log.

## 10. Check the upstream tree and the project

```bash
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
git status --short
cd "$PROJECT_ROOT"
git status --short
free -h
```

## 11. Run all steps with logging

```bash
bash scripts/G15_regression_test.sh
```

On the first run, use the downloaded copy: `bash ~/download/G15_regression_test.sh`.
The script stops after step 1, 2, 3, or 4 if a check failed, before the test starts. From step 5 on it does not stop early; every
check is recorded, and steps 7 and 9 always run.
