# G06: Build the RISC-V GNU Toolchain (`make devtools`)

The first build gate. `make devtools` downloads the prebuilt RISC-V GNU toolchain release used by
every later build step and unpacks it into `$ACE_DIR/riscv-gnu-toolchain`. This gate also records
the tarball's SHA-256 (E1) and proves that the installed compiler comes from that exact tarball (E2).
It first commits the reviewed G05b work, with revision 2 of patch 0002.

Previous gate: **G05b PASS** (see `logs/review/G05b_review.md`).

The same commands are run, with logging, by [`scripts/G06_devtools.sh`](../scripts/G06_devtools.sh).

Set the paths first:

```bash
PROJECT_ROOT=~/projects/IBM-ACE-On-QEMU-Reproduction
DOWNLOAD_DIR=~/download
```

## 1. Verify the downloaded files and all sealed evidence

```bash
cd "$DOWNLOAD_DIR"
sha256sum G06_devtools.sh G06_devtools.md
echo "71806155032f5c9dc97e6838df1453950cc1c4c9a87c7a80cd0d0357c5ae1c2e  G05b_review.md" | sha256sum -c -
echo "19d484b204f189fb65d985d06369b9439c466ce5c6916d373fd58d58e80d71b0  SOURCE_PROVENANCE.md" | sha256sum -c -
echo "5f73a4dc30e4712afc863b78e7bc1d1fc70a71bf441540ae0e585364aefb771d  build_env.sh" | sha256sum -c -
echo "3064e443ade7f24b46d5a85179afc94bf8fce1e0046a4581ea9e9549f8ed869b  0002-run-scripts-host-safety.patch" | sha256sum -c -
cd "$PROJECT_ROOT/logs"
sha256sum -c *.sha256
```

Expected: every line ends with `OK`. If any check fails, stop.

## 2. Install revision 2 of patch 0002 and confirm both patches are applied

```bash
cd "$PROJECT_ROOT"
cp "$DOWNLOAD_DIR/0002-run-scripts-host-safety.patch" patches/
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
git apply --reverse --check "$PROJECT_ROOT/patches/0001-build-parallelism.patch"
git apply --reverse --check "$PROJECT_ROOT/patches/0002-run-scripts-host-safety.patch"
```

Revision 2 of patch 0002 differs from revision 1 only in its metadata (the file mode 100755 and object ID
of `tools/ace_run_hypervisor.sh`; G05b review F1). A successful `--reverse --check` proves that revision 2
describes exactly the change that is applied. If a check fails, stop.

## 3. Commit the reviewed G05b work (local only, UTC)

```bash
cd "$PROJECT_ROOT"
cp "$DOWNLOAD_DIR/G05b_review.md" logs/review/
cp "$DOWNLOAD_DIR/SOURCE_PROVENANCE.md" docs/
cp "$DOWNLOAD_DIR/build_env.sh" scripts/
git add scripts/G05b_apply_safety_patches.sh docs/G05b_apply_safety_patches.md docs/SAFETY_AUDIT.md docs/SOURCE_PROVENANCE.md patches/README.md patches/0001-build-parallelism.patch patches/0002-run-scripts-host-safety.patch scripts/build_env.sh
git status --short
git diff --cached --quiet || TZ=UTC0 git commit -m "G05b: safety patches for build parallelism and run scripts"
git log -1 --format='%h  %aI  %an <%ae>  %s'
git show --stat --format= HEAD
cp "$DOWNLOAD_DIR/G06_devtools.sh" scripts/
cp "$DOWNLOAD_DIR/G06_devtools.md" docs/
```

`scripts/build_env.sh` holds the build settings of `docs/SAFETY_AUDIT.md`; every build gate sources it.

## 4. Record the host and source state before the build

```bash
uname -r
free -h
df -h "$PROJECT_ROOT"
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
git status --short
```

Expected: the upstream checkout shows exactly the 5 files changed by patches 0001 and 0002.

## 5. Set the build environment

```bash
source "$PROJECT_ROOT/scripts/build_env.sh"
env | grep -E '^(ACE_DIR|QEMU_SOURCE_DIR|BR2_DL_DIR|CARGO_HOME|BR2_JLEVEL|OMP_NUM_THREADS|CARGO_BUILD_JOBS)=' | sort
mkdir -p "$ACE_DIR" "$QEMU_SOURCE_DIR" "$BR2_DL_DIR" "$CARGO_HOME" "$PROJECT_ROOT/build/downloads"
```

| Variable | Value |
|---|---|
| `ACE_DIR` | `$PROJECT_ROOT/build/ace/` |
| `QEMU_SOURCE_DIR` | `$PROJECT_ROOT/build/qemu-source/` |
| `BR2_DL_DIR` | `$PROJECT_ROOT/build/dl` |
| `CARGO_HOME` | `$PROJECT_ROOT/build/cargo-home` |
| `BR2_JLEVEL`, `OMP_NUM_THREADS`, `CARGO_BUILD_JOBS` | `2` |

## 6. Download the toolchain tarball and record its SHA-256

```bash
cd "$PROJECT_ROOT/build/downloads"
TOOLCHAIN=riscv64-glibc-ubuntu-22.04-gcc-nightly-2023.09.27-nightly.tar.gz
[ -f "$TOOLCHAIN" ] || { wget -q -O "$TOOLCHAIN.part" "https://github.com/riscv-collab/riscv-gnu-toolchain/releases/download/2023.09.27/$TOOLCHAIN" && mv "$TOOLCHAIN.part" "$TOOLCHAIN"; }
ls -l "$TOOLCHAIN"
sha256sum "$TOOLCHAIN"
```

The upstream Makefile downloads the same file, unpacks it, and deletes it (`Makefile:45-48`), so its
checksum is never recorded. This step downloads it separately and keeps it. The download goes to a
`.part` file first, so an interrupted download is never mistaken for a complete one on a re-run.

## 7. Build the toolchain with the upstream Makefile

```bash
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
date -u
make -j2 devtools
date -u
```

This is the upstream procedure, unchanged: `make devtools` downloads the release tarball and unpacks it into
`$ACE_DIR/riscv-gnu-toolchain`. It is skipped when the compiler is already installed (re-run).

## 8. Verify the installed toolchain

```bash
cd "$ACE_DIR/riscv-gnu-toolchain"
ls bin | wc -l
./bin/riscv64-unknown-linux-gnu-gcc --version
./bin/riscv64-unknown-linux-gnu-gcc -dumpversion
./bin/riscv64-unknown-linux-gnu-gcc -dumpmachine
find . -path '*/usr/include/linux/version.h' -exec grep -H 'LINUX_VERSION_CODE' {} +
sha256sum bin/riscv64-unknown-linux-gnu-gcc
tar -xzOf "$PROJECT_ROOT/build/downloads/$TOOLCHAIN" riscv/bin/riscv64-unknown-linux-gnu-gcc | sha256sum
du -sh .
```

The last two hashes must be equal: the compiler installed by `make devtools` is byte-identical to the one in
the tarball whose SHA-256 was recorded in step 6. The GCC version and the kernel header version are compared
in the review with what the Buildroot configurations declare (GCC 12, headers 5.10; G05b review F7).

## 9. Check the upstream tree and the project

```bash
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
git status --short
ls *.tar.gz 2>/dev/null || echo "(no leftover tarball)"
cd "$PROJECT_ROOT"
git status --short
git check-ignore -v build/ace
free -h
```

Expected: the upstream checkout still shows only the 5 patched files and no leftover tarball;
`build/` is ignored by the project's Git; only the two new G06 files are untracked.

## 10. Run all steps with logging

```bash
bash scripts/G06_devtools.sh
```

On the first run, use the downloaded copy: `bash ~/download/G06_devtools.sh`.
The script stops after step 1, 2, 3, 5, 6, or 7 if a check failed, and still seals the log.
It can be run again after a network failure; finished downloads and the installed toolchain are reused.
