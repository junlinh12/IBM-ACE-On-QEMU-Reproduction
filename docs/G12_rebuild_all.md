# G12: Integrated Rebuild and End-to-End Artifact Audit

The upstream CI ends its build with a second full `make`, "rebuild all to include changes to cvm disk". G11 showed why
(G11 review F2): the first `make confidential_vms` copies the confidential VM's disk into the hypervisor before it adds
`ace.ko` to that disk. This gate repeats the upstream rebuild and then checks the artifacts end to end, reading the hypervisor
root file system that G13 will boot.

Previous gate: **G11 PASS** (see `logs/review/G11_review.md`).

The same commands are run, with logging, by [`scripts/G12_rebuild_all.sh`](../scripts/G12_rebuild_all.sh).

## How the rebuild matches the upstream CI

The CI runs `ACE_DIR=$(pwd)/build/ make --silent -j8`; the default target is `all: emulator tools firmware confidential_vms`
(`Makefile:35`). This gate runs exactly these four targets, in this order, as four `make` commands. It cannot run them as one
`make`, because they need different Rust toolchains on this host:

| Target | Rust toolchain | Why |
|---|---|---|
| `emulator` | none | C only |
| `tools` | `1.98.1` via `RUSTUP_TOOLCHAIN` | the TAP tool runs `cargo fmt`; the host's `stable` has no `rustfmt` (G07) |
| `firmware` | `nightly-2026-03-23` via `rust-toolchain.toml` | the security monitor needs the pinned nightly and its RISC-V target |
| `confidential_vms` | `1.98.1` via `RUSTUP_TOOLCHAIN` | its prerequisite `tools` rebuilds the TAP tool (G11 F1) |

`RUSTUP_TOOLCHAIN=1.98.1 make ...` sets the variable for that one command only. Running the targets one by one also makes the
order deterministic, where `make -j` could start independent prerequisites at the same time.

## What "the gap is closed" means here

The confidential VM's `rootfs.ext2` is regenerated in every pass (the `rootfs` step runs after the copy and rebuilds `ace.ko`),
so the copy in the hypervisor and the newest file are not expected to be byte-identical even after this rebuild. The checks
therefore test what the hypervisor will actually use. Step 8 extracts the VM kernel, the VM disk, and both TAPs from the
hypervisor's `rootfs.ext2` with `debugfs` (read-only, no root). The kernel and the TAPs must equal the current ones byte for
byte, and the disk must equal the overlay copy. Step 9 then checks that the extracted VM disk contains `ace.ko`, which the
first pass did not provide.

Set the paths first:

```bash
PROJECT_ROOT=~/projects/IBM-ACE-On-QEMU-Reproduction
DOWNLOAD_DIR=~/download
```

## 1. Verify the downloaded files and all sealed evidence

```bash
cd "$DOWNLOAD_DIR"
sha256sum G12_rebuild_all.sh G12_rebuild_all.md
echo "1e3c0a3459d845666ca01f97f5f8be5b4284cae50ff66b12d6cf2659f56285b8  G11_review.md" | sha256sum -c -
echo "e3639f17752b4e0452d53b3d9f67298b0315ed36fa93d375cb037f068723199f  SOURCE_PROVENANCE.md" | sha256sum -c -
cd "$PROJECT_ROOT/logs"
sha256sum -c *.sha256
```

Expected: every line ends with `OK`. If any check fails, stop.

## 2. Commit the reviewed G11 work (local only, UTC)

```bash
cd "$PROJECT_ROOT"
cp "$DOWNLOAD_DIR/G11_review.md" logs/review/
cp "$DOWNLOAD_DIR/SOURCE_PROVENANCE.md" docs/
git add scripts/G11_confidential_vms.sh docs/G11_confidential_vms.md docs/SOURCE_PROVENANCE.md
git status --short
git diff --cached --quiet || TZ=UTC0 git commit -m "G11: confidential VM, TAPs, kvmtool (make confidential_vms)"
git log -1 --format='%h  %aI  %an <%ae>  %s'
git show --stat --format= HEAD
cp "$DOWNLOAD_DIR/G12_rebuild_all.sh" scripts/
cp "$DOWNLOAD_DIR/G12_rebuild_all.md" docs/
```

`docs/SOURCE_PROVENANCE.md` now records the dtc and kvmtool commits built in G11 and the confidential VM's extra downloads.

## 3. Record the host and source state, and check memory and disk

```bash
uname -r
free -h
df -h "$PROJECT_ROOT"
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
git status --short
test "$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)" -ge 4194304
test "$(df -BG --output=avail "$PROJECT_ROOT" | tail -n 1 | tr -dc '0-9')" -ge 10
```

## 4. Set the build environment and record the images before the rebuild

```bash
source "$PROJECT_ROOT/scripts/build_env.sh"
env | grep -E '^(ACE_DIR|QEMU_SOURCE_DIR|BR2_DL_DIR|CARGO_HOME|BR2_JLEVEL|OMP_NUM_THREADS|CARGO_BUILD_JOBS|WGETRC)=' | sort
FW="$ACE_DIR/security-monitor/opensbi/platform/generic/firmware"
CVM="$ACE_DIR/confidential_vms/linux_vm/buildroot/images"
OV="$ACE_DIR/hypervisor/overlay/root/linux_vm"
HV="$ACE_DIR/hypervisor/buildroot/images/rootfs.ext2"
sha256sum "$FW/fw_payload.elf" "$ACE_DIR/security-monitor/libace.a" "$HV" "$CVM/rootfs.ext2" "$OV/rootfs.ext2" "$CVM/cove_tap_qemu" "$CVM/cove_tap_kvmtool"
```

These are the G10 and G11 values (`fw_payload.elf` `6a41b581...`, hypervisor `rootfs.ext2` `a1e289a0...`, VM disk `d392fdab...`,
overlay copy `030d9dcc...`), recorded again so that the review can show exactly what the rebuild changed.

## 5. Check that Rust 1.98.1 still equals the host's stable

```bash
test "$(rustup run stable rustc --version)" = "$(RUSTUP_TOOLCHAIN=1.98.1 rustc --version)"
```

## 6. Rebuild all targets in the order of the upstream all target

```bash
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
date -u
make -j2 emulator
RUSTUP_TOOLCHAIN=1.98.1 make -j2 tools
make -j2 firmware
RUSTUP_TOOLCHAIN=1.98.1 make -j2 confidential_vms
date -u
```

Expected: `emulator` finds QEMU installed and does nothing; `tools` copies the scripts and finds the TAP tool up to date;
`firmware` rebuilds the security monitor and OpenSBI (the hypervisor kernel is unchanged, so the payload is the same); and
`confidential_vms` skips the VM's Buildroot build, regenerates `ace.ko` and the TAPs, copies the VM files into the hypervisor's
overlay, and repacks both root file systems. The script stops after any of the four commands if it failed.

## 7. Verify the firmware and its payload

```bash
sha256sum "$FW/fw_payload.elf" "$FW/fw_payload.bin" "$ACE_DIR/security-monitor/libace.a"
test "$(sha256sum < "$ACE_DIR/hypervisor/buildroot/images/Image" | cut -d' ' -f1)" = 75a0db25e8f28f415d93b490bbaf4f1bf4b31b6c22685556bfe32adf056308d7
python3 -c 'import sys; fw = open(sys.argv[1], "rb").read(); img = open(sys.argv[2], "rb").read(); i = fw.find(img); print("payload offset:", hex(i) if i >= 0 else "NOT FOUND"); sys.exit(i < 0)' "$FW/fw_payload.bin" "$ACE_DIR/hypervisor/buildroot/images/Image"
```

The rebuilt firmware must still carry the G09 kernel. Whether its hash equals G10's shows whether the firmware build is
reproducible on this host.

## 8. Read the confidential VM back out of the hypervisor root file system

```bash
CHK="$PROJECT_ROOT/build/g12-check"
rm -rf "$CHK"
mkdir -p "$CHK"
debugfs -R "ls -l /root" "$HV"
debugfs -R "dump /root/linux_vm/Image $CHK/Image" "$HV"
debugfs -R "dump /root/linux_vm/rootfs.ext2 $CHK/rootfs.ext2" "$HV"
debugfs -R "dump /root/linux_vm/cove_tap_qemu $CHK/cove_tap_qemu" "$HV"
debugfs -R "dump /root/linux_vm/cove_tap_kvmtool $CHK/cove_tap_kvmtool" "$HV"
sha256sum "$CHK"/* "$CVM/Image" "$CVM/cove_tap_qemu" "$CVM/cove_tap_kvmtool" "$OV/rootfs.ext2" "$CVM/rootfs.ext2"
cmp "$CHK/Image" "$CVM/Image"
cmp "$CHK/cove_tap_qemu" "$CVM/cove_tap_qemu"
cmp "$CHK/cove_tap_kvmtool" "$CVM/cove_tap_kvmtool"
cmp "$CHK/rootfs.ext2" "$OV/rootfs.ext2"
```

`debugfs` opens the image read-only, so nothing is changed. `build/g12-check` is emptied first, so a file left from an earlier run
can never stand in for a missing one. Each `cmp` fails if the two files differ: the VM kernel and the TAPs carried by the hypervisor
must be exactly the current ones, and the carried VM disk must be the overlay copy. The listing of `/root` shows the test scripts
and `lkvm-static` that G14 and G15 will use.

## 9. Check that the carried VM disk contains ace.ko

```bash
debugfs -R "ls -l /root/ace_module" "$CHK/rootfs.ext2"
debugfs -R "dump /root/ace_module/ace.ko $CHK/ace.ko" "$CHK/rootfs.ext2"
sha256sum "$CHK/ace.ko" "$ACE_DIR/confidential_vms/linux_vm/overlay/root/ace_module/ace.ko"
test -s "$CHK/ace.ko"
"$ACE_DIR/tools/cove-tap-tool" measure --base-address=0x80000000 --kernel-file="$CHK/Image"
"$ACE_DIR/tools/cove-tap-tool" measure --base-address=0x80200000 --kernel-file="$CHK/Image"
```

`test -s` fails unless the VM disk inside the hypervisor contains a non-empty `ace.ko`: this is the check that the gap of G11 is
closed. The two measurements of the carried VM kernel must equal the PCR 4 values of G11 (`0x4e73d007...da33` and
`0x968eb5f1...ad18`), because the VM kernel was not rebuilt.

## 10. Record the final images and check the upstream tree and the project

```bash
sha256sum "$HV" "$FW/fw_payload.elf"
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
git status --short
git diff --stat
git -C hypervisor/buildroot status --short
cd "$PROJECT_ROOT"
git status --short
free -h
df -h "$PROJECT_ROOT"
```

The first line records the two files that G13 boots: the firmware and the hypervisor root file system.

## 11. Run all steps with logging

```bash
bash scripts/G12_rebuild_all.sh
```

On the first run, use the downloaded copy: `bash ~/download/G12_rebuild_all.sh`.
The script stops after step 1 to 6 if a check failed, and still seals the log.
