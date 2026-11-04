# G11: Build the Confidential VM and Repack the Hypervisor (`make confidential_vms`)

`make confidential_vms` builds the confidential VM (TVM): a second Buildroot image with its own Linux 6.3-rc4 kernel (CoVE
guest patches), a small root file system, and the kernel module `ace.ko` that asks the security monitor for attestation and
the demo secret. It then measures the VM's kernel and writes the TVM attestation payloads (TAPs), builds dtc and kvmtool,
and repacks the hypervisor's root file system so that the hypervisor carries the VM, the TAPs, kvmtool, and the test scripts.

Previous gate: **G10 PASS** (see `logs/review/G10_review.md`).

The same commands are run, with logging, by [`scripts/G11_confidential_vms.sh`](../scripts/G11_confidential_vms.sh).

| Item | Value | Source |
|---|---|---|
| Make target | `confidential_vms`: prerequisites `setup devtools hypervisor tools`; then `linux_vm buildroot`, `linux_vm overlay rootfs`, `hypervisor rootfs` | `Makefile:60-63` |
| Confidential VM | Buildroot with `confidential-vms/linux_vm/configurations/`, kernel patches `confidential-vms/linux_vm/patches/linux/6.3-rc4/`, root file system 128 MiB | `confidential-vms/linux_vm/Makefile:13-28,44-62` |
| `ace.ko` | built from `confidential-vms/linux_vm/overlay/root/ace_module/` against the VM's kernel | `confidential-vms/linux_vm/Makefile:77` |
| TAPs | `cove-tap-tool measure` of the VM kernel at `0x80000000` (QEMU) and `0x80200000` (kvmtool), then `generate --pcrs 4=<digest> --secrets 0=0xc0ffeec0ffeec0ffeec0ffee` | `confidential-vms/linux_vm/Makefile:81-90` (SAFETY_AUDIT A15) |
| dtc, kvmtool | cloned from `git://git.kernel.org/.../dtc.git` (default branch) and `github.com/wojciechozga/kvmtool` branch `cove-integration-03072023` | `hypervisor/Makefile:74-92` |
| Linux source | the verified `build/dl/linux/linux-6.3-rc4.tar.gz` from G09 | `docs/SOURCE_PROVENANCE.md` |

**Why `RUSTUP_TOOLCHAIN=1.98.1` is set.** `tools` is a prerequisite of `confidential_vms` and always runs (`.PHONY`). It
rebuilds the TAP tool, whose Makefile runs `cargo fmt`, and the host's `stable` toolchain has no `rustfmt` (G07 first-run
review). As in G07, the gate selects Rust 1.98.1 for this make only and first checks that it prints the same version line as
`stable`. Nothing else in this target compiles Rust, so the security monitor is not affected.

**A known gap in the upstream sequence.** The `overlay` step copies the VM's `rootfs.ext2` into the hypervisor's overlay
(`confidential-vms/linux_vm/Makefile:86`) before the `rootfs` step rebuilds that root file system with `ace.ko`
(`confidential-vms/linux_vm/Makefile:93-94`). After the first `make confidential_vms`, the hypervisor therefore carries the
VM disk without `ace.ko`. The upstream CI closes this with a second full `make` ("rebuild all to include changes to cvm
disk"); in this project that is G12. Step 9 records the gap.

Set the paths first:

```bash
PROJECT_ROOT=~/projects/IBM-ACE-On-QEMU-Reproduction
DOWNLOAD_DIR=~/download
```

## 1. Verify the downloaded files and all sealed evidence

```bash
cd "$DOWNLOAD_DIR"
sha256sum G11_confidential_vms.sh G11_confidential_vms.md
echo "6f56d0f0247bf57bf9275cd5ded32487a0718f25989d2af56eb4b73263e222db  G10_review.md" | sha256sum -c -
cd "$PROJECT_ROOT/logs"
sha256sum -c *.sha256
```

Expected: every line ends with `OK`. If any check fails, stop.

## 2. Commit the reviewed G10 work (local only, UTC)

```bash
cd "$PROJECT_ROOT"
cp "$DOWNLOAD_DIR/G10_review.md" logs/review/
git add scripts/G10_firmware.sh docs/G10_firmware.md
git status --short
git diff --cached --quiet || TZ=UTC0 git commit -m "G10: OpenSBI with the ACE security monitor (make firmware)"
git log -1 --format='%h  %aI  %an <%ae>  %s'
git show --stat --format= HEAD
cp "$DOWNLOAD_DIR/G11_confidential_vms.sh" scripts/
cp "$DOWNLOAD_DIR/G11_confidential_vms.md" docs/
```

## 3. Record the host and source state, and check memory and disk

```bash
uname -r
free -h
df -h "$PROJECT_ROOT"
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
git status --short
test "$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)" -ge 4194304
test "$(df -BG --output=avail "$PROJECT_ROOT" | tail -n 1 | tr -dc '0-9')" -ge 30
```

The upstream checkout is expected to show the 5 patched files and the patched OpenSBI submodule (G10).

## 4. Set the build environment and record the files that will change

```bash
source "$PROJECT_ROOT/scripts/build_env.sh"
env | grep -E '^(ACE_DIR|QEMU_SOURCE_DIR|BR2_DL_DIR|CARGO_HOME|BR2_JLEVEL|OMP_NUM_THREADS|CARGO_BUILD_JOBS|WGETRC)=' | sort
sha256sum "$ACE_DIR/hypervisor/buildroot/images/rootfs.ext2" "$ACE_DIR/tools/cove-tap-tool"
```

The last line records, before the build, the hashes of the hypervisor's root file system (G09: `bf135f13...`) and the TAP
tool (G07: `f2a6d7dc...`), so that step 9 can show what the repack changed and step 7 whether the rebuilt TAP tool is
identical. It needs `ACE_DIR`, so it comes after `build_env.sh`.

## 5. Build the confidential VM with the upstream Makefile

```bash
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
export RUSTUP_TOOLCHAIN=1.98.1
test "$(rustup run stable rustc --version)" = "$(rustc --version)"
date -u
make -j2 confidential_vms
date -u
unset RUSTUP_TOOLCHAIN
```

The second line fails unless Rust 1.98.1 is still the same release as the host's `stable` (as checked in G07).
The confidential VM's Buildroot runs with `BR2_JLEVEL=2` (patch 0001) and reuses the downloads in `build/dl`, including the
verified Linux tarball; kvmtool is built with `-j$(shell nproc)` = 2 (patch 0001, `OMP_NUM_THREADS=2`).

## 6. Verify the confidential VM

```bash
CVM="$ACE_DIR/confidential_vms/linux_vm/buildroot"
ls -l "$CVM/images"
sha256sum "$CVM/images/Image" "$CVM/images/rootfs.ext2"
grep -a -o -m 1 'Linux version [[:print:]]*' "$CVM/images/Image"
cat "$CVM"/build/linux-[0-9]*/.applied_patches_list
grep -E '^CONFIG_(RISCV_COVE[A-Z_]*|MODULES)=' "$CVM"/build/linux-[0-9]*/.config
find "$ACE_DIR/confidential_vms/linux_vm/overlay" -name '*.ko' -exec sha256sum {} +
```

| Check | Why |
|---|---|
| SHA-256 of the VM's `Image` and `rootfs.ext2` | E2 for the confidential VM |
| kernel banner | the compiler that built the VM kernel |
| `.applied_patches_list` | the CoVE guest patches from `confidential-vms/linux_vm/patches/linux/6.3-rc4/` were applied |
| `CONFIG_RISCV_COVE*`, `CONFIG_MODULES` | the kernel can run as a CoVE guest and load `ace.ko` |
| `ace.ko` | the module that the attestation test loads in the VM (G05b review F3) |

## 7. Record the TAPs and the measurements they contain

```bash
ls -l "$CVM/images/cove_tap_qemu" "$CVM/images/cove_tap_kvmtool"
sha256sum "$CVM/images/cove_tap_qemu" "$CVM/images/cove_tap_kvmtool"
"$ACE_DIR/tools/cove-tap-tool" measure --base-address=0x80000000 --kernel-file="$CVM/images/Image"
"$ACE_DIR/tools/cove-tap-tool" measure --base-address=0x80200000 --kernel-file="$CVM/images/Image"
sha256sum "$ACE_DIR/tools/cove-tap-tool"
```

The Makefile computes the measurement inside a make function and never prints it. Running `measure` again on the same
kernel, with the same base addresses, records the values that were written into the TAPs as PCR 4. This is the reference
that E6 compares with the measurement reported during local attestation (G14).

## 8. Record dtc and kvmtool

```bash
K="$ACE_DIR/hypervisor/kvmtool"
git -C "$K/dtc" remote get-url origin
git -C "$K/dtc" log -1 --format='%H %cI %s'
git -C "$K/kvmtool" remote get-url origin
git -C "$K/kvmtool" rev-parse --abbrev-ref HEAD
git -C "$K/kvmtool" log -1 --format='%H %cI %s'
file "$K/kvmtool/lkvm-static"
sha256sum "$K/kvmtool/lkvm-static"
```

Neither repository is pinned to a commit by the upstream Makefile (G02 review F6). These lines record the commits that were
actually built; G05 observed dtc `c22868416b8d` and kvmtool `177a4df3a0ff`.

## 9. Check the repacked hypervisor root file system

```bash
find "$ACE_DIR/hypervisor/overlay" -type f | sort
sha256sum "$ACE_DIR/hypervisor/overlay/root/linux_vm/"*
sha256sum "$ACE_DIR/hypervisor/buildroot/images/rootfs.ext2"
sha256sum "$CVM/images/rootfs.ext2" "$ACE_DIR/hypervisor/overlay/root/linux_vm/rootfs.ext2"
```

The overlay is what was added to the hypervisor's root file system: test scripts, `lkvm-static`, and in `linux_vm/` the VM's
kernel, root file system, and TAPs. The hypervisor's `rootfs.ext2` must differ from G09's.
The last line shows the known gap: the VM's current `rootfs.ext2` (rebuilt with `ace.ko`) and the copy in the hypervisor's
overlay are expected to differ after this first pass. G12 must make them equal.

## 10. Record the downloaded sources

```bash
ls "$BR2_DL_DIR"
find "$BR2_DL_DIR" -mindepth 2 -maxdepth 2 -type f ! -name .lock -exec sha256sum {} + | sort -k 2
du -sh "$BR2_DL_DIR" "$ACE_DIR/confidential_vms" "$ACE_DIR/hypervisor"
```

Any package that the confidential VM needs and the hypervisor did not appears here as a new entry compared with G09.

## 11. Check the upstream tree and the project

```bash
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
git status --short
git diff --stat
git -C hypervisor/buildroot status --short
cd "$PROJECT_ROOT"
git status --short
free -h
df -h "$PROJECT_ROOT"
```

Expected: the upstream checkout shows the 5 patched files and the patched OpenSBI submodule; any further change was made by
the build (for example `cargo fmt` of the TAP tool) and is listed for the review. The project shows only the two new G11 files.

## 12. Run all steps with logging

```bash
bash scripts/G11_confidential_vms.sh
```

On the first run, use the downloaded copy: `bash ~/download/G11_confidential_vms.sh`.
The script stops after step 1, 2, 3, 4, or 5 if a check failed, and still seals the log.
After a failed confidential-VM build, running the script again restarts that Buildroot build from the beginning
(`confidential-vms/linux_vm/Makefile:47`); downloads in `build/dl` are reused.
