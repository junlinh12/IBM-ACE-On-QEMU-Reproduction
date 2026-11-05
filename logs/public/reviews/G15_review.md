# G15 Review: Upstream Regression Test (`ace test`), Unchanged

| Field | Value |
|---|---|
| Gate | G15 Regression Test |
| Run | `G15_20261104T125134Z_jrn7fa` |
| Input script SHA-256 | `af2ce6aa1e0adddb9e55c80407450a13fc3544ad0d70d1104d4331d09313f6d2` |
| Raw log SHA-256 | `c0f52019505a19ad183bd2eeb0ef1dc687f8a8c781e9b12c510fec1f0ce2e959` |
| Result files (sealed through this gate's log) | `logs/G15_ace_test_results_20261104T125135Z.log`, SHA-256 `dbe66e4e751ecb80adbf7b5a08abd7288125e9b93637798e64d3d6fc82d11e2c`; `logs/G15_run_tests_20261104T125135Z.log`, SHA-256 `436f1131f4ca5af9e51d8cd05091314ca8fe23bd38c75f89510f831ef915dae4` |
| Reviewed material | masked review log |
| Previous gate | G14 PASS; checkpoint 3 recorded |
| **Judgement** | **PASS** (E8: the upstream regression test ran unchanged; 2 tests run, 2 passed, 0 failed, 0 skipped) |

## Criteria

| Criterion | Evidence (step) | Result |
|---|---|---|
| Inputs and evidence intact | 2 hash checks OK; all 21 seal files of G00-G14 OK (1) | OK |
| G14 work and checkpoint 3 committed in UTC | `03ddfa0`, 2 files; `CHECKPOINT_3.md` in `logs/review/` (2) | OK |
| Host ready | 13,608,548 kB available; no QEMU of this project; port in the test's range already in use: <port> (3) | OK |
| Reviewed images | `fw_payload.elf` `6a41b581...`; pristine and disk `cc07c2dc...` (4) | OK |
| Upstream test ran unchanged | `$ACE_DIR/tools/ace test`; SSH on random port 4005 (no collision); 42 s (12:51:35-12:52:17 UTC); exit status 0 (5) | OK |
| **E8 by result lines** | `test_attestation: success` exactly once; `test_smp: success` exactly once; no `: failed` (6) | OK |
| Test stopped its QEMU | no QEMU of this project left; `pkill` had nothing to stop (7) | OK |
| Results kept and sealed; disk restored | both files in `logs/`, read-only, hashed; disk `fff96361...` after the test, pristine `cc07c2dc...` restored (9) | OK |
| Upstream tree and project | the 5 patched files and the patched OpenSBI submodule; only the G15 files untracked (10) | OK |

## Findings and actions

**F1. The upstream regression test passes on the reproduced system.** `test_attestation` (confidential VM with 1 vCPU, `ace.ko`, secret
exactly once) and `test_smp` (confidential VM with 2 vCPUs, marker file of its file system) both succeeded, inside the hypervisor
started by the upstream scripts themselves. Together with G14, the attestation succeeded in two independent boots of the platform.

**F2. In daemon mode QEMU also opens a VNC server on `127.0.0.1:5900`.** `ace_run_hypervisor.sh --daemonize` replaces `-nographic` by
`-daemonize` and gives no display option, so QEMU starts its default VNC display. It listens on the loopback address only and ends
with QEMU, so nothing is exposed to the network; it would collide with another VNC server on the host using port 5900. Recorded for
the report; no patch.

**F3. The result file contains the nested SSH client's notices.** `selftest.sh` runs the tests with `2>&1 > $i.log`, which sends their
standard error to the result stream, so the host-key notices of `ssh -y` appear in `ace_test_results` between the result lines.
The E8 rule matches whole result lines and is not affected. This also shows why the line-based rule is safer than counting the
file's lines.

**F4. The tests' own logs did not reach the disk image.** `test_attestation.log` and `tmp_run_vm.log` exist on the hypervisor's disk with
size 0, and the other logs are missing, because the upstream test ends QEMU with `kill -9` before the guest writes its file data
back. As expected in the G15 document, this step was best effort; the evidence for the tests is the result file, and G14 recorded
the same test step by step.

## Next

The owner decides whether to add the optional negative control (checkpoint 3, section 6) before G16: a TAP with a wrong PCR 4 must not
release the secret. Then G16: publication audit (sanitization, Git history, licenses).
