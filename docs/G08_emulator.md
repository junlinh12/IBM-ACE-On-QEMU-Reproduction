# G08: Build QEMU for the Emulated RISC-V Platform (`make emulator`)

`make emulator` downloads the QEMU 8.2.1 source and builds `qemu-system-riscv64` into `$ACE_DIR/qemu`. This QEMU
emulates the RISC-V machine on which OpenSBI, the ACE security monitor, and the Linux hypervisor run (G13). It is
not the distribution's QEMU in `/usr/bin` (G00 review F2); the run scripts call it by its path under `$ACE_DIR`.

Previous gate: **G07 PASS** (see `logs/review/G07_review.md`).

The same commands are run, with logging, by [`scripts/G08_emulator.sh`](../scripts/G08_emulator.sh).

| Item | Value | Source |
|---|---|---|
| QEMU version | 8.2.1 | `Makefile:13` |
| Configuration | `--enable-slirp --enable-kvm --target-list=riscv64-softmmu` | `Makefile:85` |
| Source location | `$QEMU_SOURCE_DIR` (outside the upstream checkout) | `scripts/build_env.sh` (SAFETY_AUDIT A11) |
| Features used later | `-machine virt -cpu rv64 -bios none`, user networking (slirp) | `tools/ace_run_hypervisor.sh:57-69` |

New in this gate (SAFETY_AUDIT revision 2): the script stops before building if less than 4 GiB of memory is
available (A16), every time printed by the script is in UTC (A17), and `wget` prints one line per download
(`WGETRC`, `scripts/wgetrc`).

Set the paths first:

```bash
PROJECT_ROOT=~/projects/IBM-ACE-On-QEMU-Reproduction
DOWNLOAD_DIR=~/download
```

## 1. Verify the downloaded files and all sealed evidence

```bash
cd "$DOWNLOAD_DIR"
sha256sum G08_emulator.sh G08_emulator.md
echo "1c4b151f9e3512fe3a437ebd061d2d18d2e1b5e21da759c5a69c5bc77e70df63  G07_review.md" | sha256sum -c -
echo "6a353adb19ed00865c6e5b29bfe46098ccab0d045200aa41a78396465cb490bb  SAFETY_AUDIT.md" | sha256sum -c -
echo "30c33c4311e42358850c421265e6613770ab85a9971f189710fc6c4917c731b2  SOURCE_PROVENANCE.md" | sha256sum -c -
echo "dd8de984968d097bc882ab5f3dd47286c9fb71652864e0ec0db00a5260f90de8  build_env.sh" | sha256sum -c -
echo "ce1fecda74befd6a4c8d5bdcd3738434099975aa4ff8bc25a6cfeb577315e96f  wgetrc" | sha256sum -c -
cd "$PROJECT_ROOT/logs"
sha256sum -c *.sha256
```

Expected: every line ends with `OK`. If any check fails, stop.

## 2. Commit the reviewed G07 work (local only, UTC)

```bash
cd "$PROJECT_ROOT"
cp "$DOWNLOAD_DIR/G07_review.md" logs/review/
cp "$DOWNLOAD_DIR/SAFETY_AUDIT.md" docs/
cp "$DOWNLOAD_DIR/SOURCE_PROVENANCE.md" docs/
cp "$DOWNLOAD_DIR/build_env.sh" scripts/
cp "$DOWNLOAD_DIR/wgetrc" scripts/
git add scripts/G07_tools.sh docs/G07_tools.md docs/SAFETY_AUDIT.md docs/SOURCE_PROVENANCE.md scripts/build_env.sh scripts/wgetrc
git status --short
git diff --cached --quiet || TZ=UTC0 git commit -m "G07: ACE tools and TAP tool (make tools)"
git log -1 --format='%h  %aI  %an <%ae>  %s'
git show --stat --format= HEAD
cp "$DOWNLOAD_DIR/G08_emulator.sh" scripts/
cp "$DOWNLOAD_DIR/G08_emulator.md" docs/
```

The commit contains the G07 script and document (revision 2), SAFETY_AUDIT revision 2, the updated
SOURCE_PROVENANCE, and `build_env.sh` revision 2 with `scripts/wgetrc`.

## 3. Record the host and source state, and check the free memory

```bash
uname -r
free -h
df -h "$PROJECT_ROOT"
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
git status --short
test "$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)" -ge 4194304
```

The last line fails if less than 4 GiB (4194304 kB) is available (SAFETY_AUDIT A16). The host is shared, and the
memory available to this project changes with the other workloads; if the check fails, stop and run the gate later.

## 4. Set the build environment

```bash
source "$PROJECT_ROOT/scripts/build_env.sh"
env | grep -E '^(ACE_DIR|QEMU_SOURCE_DIR|BR2_DL_DIR|CARGO_HOME|BR2_JLEVEL|OMP_NUM_THREADS|CARGO_BUILD_JOBS|WGETRC)=' | sort
```

## 5. Build QEMU with the upstream Makefile

```bash
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
date -u
make -j2 emulator
date -u
```

This is the upstream procedure, unchanged (`Makefile:76-88`): download `qemu-8.2.1.tar.xz` into `$QEMU_SOURCE_DIR`,
unpack it, configure, build (output discarded by the Makefile; errors are still logged), and install into
`$ACE_DIR/qemu`. QEMU's build passes make's `-j2` on to ninja. It is skipped when QEMU is already installed (re-run).

## 6. Verify the emulator and record the source tarball

```bash
Q="$ACE_DIR/qemu/bin/qemu-system-riscv64"
"$Q" --version
"$Q" -machine help | grep -w virt
"$Q" -cpu help | grep -w rv64
ldd "$Q" | grep -E 'slirp|not found'
sha256sum "$Q"
ls -l "$QEMU_SOURCE_DIR/qemu-8.2.1.tar.xz"
sha256sum "$QEMU_SOURCE_DIR/qemu-8.2.1.tar.xz"
/usr/bin/qemu-system-riscv64 --version
du -sh "$ACE_DIR/qemu" "$QEMU_SOURCE_DIR"
```

Expected: version 8.2.1; the `virt` machine and the `rv64` CPU used by `tools/ace_run_hypervisor.sh` are listed;
the binary is linked with `libslirp` (user networking, needed for the SSH port forward) and no library is
`not found`. The Makefile keeps the source tarball, so its SHA-256 can be recorded directly (E1); the binary's
SHA-256 is recorded for E2. The distribution's QEMU in `/usr/bin` is printed only to show that it is a different
program, which the reproduction does not use.

## 7. Check the upstream tree and the project

```bash
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
git status --short
cd "$PROJECT_ROOT"
git status --short
free -h
```

Expected: the upstream checkout still shows only the 5 patched files (the QEMU source is outside it);
the project shows only the two new G08 files.

## 8. Run all steps with logging

```bash
bash scripts/G08_emulator.sh
```

On the first run, use the downloaded copy: `bash ~/download/G08_emulator.sh`.
The script stops after step 1, 2, 3, 4, or 5 if a check failed, and still seals the log.
