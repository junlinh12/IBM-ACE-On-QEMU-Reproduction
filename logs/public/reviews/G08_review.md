# G08 Review: Build QEMU for the Emulated RISC-V Platform (`make emulator`)

| Field | Value |
|---|---|
| Gate | G08 Emulator, third run |
| Run | `G08_20261102T112702Z_6hnn8n` |
| Input script SHA-256 | `d93a60b04dfdf92ae489167d4a4aeb7a3cc2655eb792612568a4ae125c6285bf` |
| Raw log SHA-256 | `795e0b83fa81c62d1ce2e57d8198c6a1655b5216152c9886047079b4957b0abb` |
| Reviewed material | masked review log (888 lines) |
| Previous runs | `G08_20261102T091256Z_nnjq89` and `G08_20261102T112611Z_dl5kmx`: STOPPED at step 1 (input files not downloaded; see F5) |
| Previous gate | G07 PASS |
| **Judgement** | **PASS** (E1: QEMU source hashed and confirmed by two independent distributions; E2: emulator built) |

## Criteria

| Criterion | Evidence (step) | Result |
|---|---|---|
| Inputs and earlier evidence intact | 5 hash checks OK; 30 sealed files OK, including both stopped G08 runs (1) | OK |
| G07 work committed in UTC | `968706f`, 6 files (G07 rev. 2, SAFETY_AUDIT rev. 2, SOURCE_PROVENANCE, `build_env.sh` rev. 2, `wgetrc`) (2) | OK |
| Enough memory before building | `MemAvailable` 7,755,632 kB >= 4,194,304 kB (3) | OK |
| Build settings in effect | 8 variables, including `WGETRC` (4) | OK |
| `make -j2 emulator` succeeded | 2 min 11 s (11:27:02-11:29:13 UTC); no line with `error` or `warning` (5) | OK |
| Download logged on one line | `URL:https://download.qemu.org/qemu-8.2.1.tar.xz [129848448/129848448]` (5) | OK |
| Build environment | Python 3.12.3, GCC 13.3.0, ninja 1.11.1, meson in QEMU's own venv; `slirp support: YES 4.7.0` (5) | OK |
| Emulator as required by the run scripts | `QEMU emulator version 8.2.1`; machine `virt`; CPU `rv64`; `libslirp.so.0` linked, nothing `not found` (6) | OK |
| Binary and source recorded | `qemu-system-riscv64` SHA-256 `f01d93bae8cad6cab6fbb156e2372bbf430a4b930104f0a75af56c97d53864fa`; `qemu-8.2.1.tar.xz` 129,848,448 bytes, SHA-256 `8562751158175f9d187c5f22b57555abe3c870f0325c8ced12c34c6d987729be` (6) | OK |
| Different from the distribution's QEMU | `/usr/bin/qemu-system-riscv64` is `8.2.2 (Debian 1:8.2.2+ds-0ubuntu1.18)` (6) | OK |
| Upstream tree and project | 5 patched files only; only the G08 files untracked (7) | OK |

## Findings and actions

**F1. `KVM support: NO` in QEMU's configuration summary is expected.** QEMU uses KVM only when the host and the
emulated machine have the same architecture; here the host is x86_64 and the target is riscv64, so the emulated
RISC-V platform runs under TCG emulation, as planned (G00 review F7). KVM is used inside the emulated RISC-V Linux,
by the nested QEMU built in G09 (G05b review F6). `--enable-kvm` in `Makefile:85` has no effect on this host. No action.

**F2. The QEMU source tarball is independently confirmed.** Its SHA-256 equals the hash pinned for QEMU 8.2.1 by the
Chimera Linux package definition (`8562751158175f9d...729be`) and by nixpkgs (SRI `sha256-hWJ1EVgXX50YfF8itXVVq+PIcPAyXIztEsNMbZh3Kb4=`,
which decodes to the same value). E1 for QEMU rests on external evidence, not only on this host's download.

**F3. The file date differs from the release date, the content does not.** `ls -l` shows the server's date
`Oct 27 2024`, while QEMU 8.2.1 was announced on 2024-01-29. The content hash matches the hashes that the
distributions pinned when they packaged 8.2.1, so the file is the released tarball. No action.

**F4. QEMU's parallelism is not visible in the log.** The Makefile discards the output of the main QEMU build
(`Makefile:86`), so the ninja job count cannot be read from the log. Memory stayed at 7.4 GiB available before and
after the build. No action.

**F5. Two runs stopped at the input check.** The first run found 4 of the 7 input files missing; the second found
`wgetrc` missing; the owner then downloaded them again. Both stopped at step 1, before any commit or build, and their
logs are kept and sealed. This is the input check working as designed.

**F6. Times are now printed in UTC.** With `TZ=UTC0` in the harness, no local time appears in the log.

## Next gate

G09: `make hypervisor` (Buildroot: Linux 6.3-rc4 with the CoVE/ACE patches and the hypervisor root file system,
including the nested QEMU). Record the downloaded sources and their SHA-256, the patches Buildroot applied (including
QEMU's `cove.patch`), and the resulting images. This is the longest build so far. Checkpoint 2 follows G09.
