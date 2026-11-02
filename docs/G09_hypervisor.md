# G09: Build the RISC-V Linux Hypervisor Image (`make hypervisor`)

`make hypervisor` runs Buildroot to produce the untrusted host side of the experiment: a RISC-V Linux 6.3-rc4 kernel
with the CoVE and ACE patches and KVM, and a root file system that contains, among other things, the nested QEMU used
to start the confidential VM. These run on the emulated RISC-V platform (G08) on top of OpenSBI and the ACE security
monitor (G10).

Previous gate: **G08 PASS**. The first run of G09 was **BLOCKED** (`logs/review/G09_run1_review.md`): Buildroot could not
download the Linux 6.3-rc4 source. For a release candidate, Buildroot 2023.11 downloads a snapshot that cgit generates
on demand at `https://git.kernel.org/torvalds/t/linux-6.3-rc4.tar.gz`, and that endpoint does not serve automated tools
reliably today. This revision builds the same source, tag `v6.3-rc4`, from kernel.org's Git service, verifies it against
kernel.org and the GitHub mirror, and places it where Buildroot looks before downloading. No upstream file is modified.

The same commands are run, with logging, by [`scripts/G09_hypervisor.sh`](../scripts/G09_hypervisor.sh).

| Item | Value | Source |
|---|---|---|
| What `make hypervisor` builds | `hypervisor/Makefile` target `all` = `setup buildroot` (kernel and root file system) | `Makefile:51-52`, `hypervisor/Makefile:31-55` |
| Not built here | dtc, kvmtool, the overlay, and the final root file system: built by `make confidential_vms` (G11) | `Makefile:60-63`, `hypervisor/Makefile:57-92` |
| Buildroot | submodule `hypervisor/buildroot`, 2023.11 | G02 |
| Kernel | Linux 6.3-rc4 with `hypervisor/patches/linux/6.3-rc4/` | hypervisor Buildroot configuration |
| Nested QEMU | Buildroot's QEMU package, patched with `hypervisor/patches/qemu/8.1.1/cove.patch` if the version matches | G05b review F6 |
| Jobs | `BR2_JLEVEL=2` (patch 0001) | SAFETY_AUDIT A1 |
| Downloads | `build/dl` (`BR2_DL_DIR`) | SAFETY_AUDIT A11 |
| Linux source in this revision | `build/dl/linux/linux-6.3-rc4.tar.gz`, created with `git archive` from tag `v6.3-rc4` | steps 6-8 |
| Toolchain used by Buildroot | Bootlin's prebuilt RISC-V toolchain (Buildroot's default external toolchain), not the one from G06 | G09 first-run review |

This is the longest build so far (tens of minutes or more with 2 jobs). Running it inside `tmux` keeps it alive if the
terminal or SSH session closes.

Set the paths first:

```bash
PROJECT_ROOT=~/projects/IBM-ACE-On-QEMU-Reproduction
DOWNLOAD_DIR=~/download
```

## 1. Verify the downloaded files and all sealed evidence

```bash
cd "$DOWNLOAD_DIR"
sha256sum G09_hypervisor.sh G09_hypervisor.md
echo "031f6025b0755cf1705af33934f5fe1bf886c51808d8545aef82191a2aed4a4d  G08_review.md" | sha256sum -c -
echo "e192c293a98ef41d3476579bb03e9be1a250c348aecf31641236fa741e1e39c7  G09_run1_review.md" | sha256sum -c -
cd "$PROJECT_ROOT/logs"
sha256sum -c *.sha256
```

Expected: every line ends with `OK`. If any check fails, stop.

## 2. Commit the reviewed G08 work (local only, UTC)

```bash
cd "$PROJECT_ROOT"
cp "$DOWNLOAD_DIR/G08_review.md" logs/review/
cp "$DOWNLOAD_DIR/G09_run1_review.md" logs/review/
git add scripts/G08_emulator.sh docs/G08_emulator.md
git status --short
git diff --cached --quiet || TZ=UTC0 git commit -m "G08: QEMU 8.2.1 for the emulated platform (make emulator)"
git log -1 --format='%h  %aI  %an <%ae>  %s'
cp "$DOWNLOAD_DIR/G09_hypervisor.sh" scripts/
cp "$DOWNLOAD_DIR/G09_hypervisor.md" docs/
```

The G08 work was already committed by the first G09 run, so no new commit is made here.

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

The last two lines fail if less than 4 GiB of memory (SAFETY_AUDIT A16) or less than 30 GB of disk is available;
Buildroot keeps a separate directory per package, so the build needs much more disk than the earlier gates.

## 4. Set the build environment

```bash
source "$PROJECT_ROOT/scripts/build_env.sh"
env | grep -E '^(ACE_DIR|QEMU_SOURCE_DIR|BR2_DL_DIR|CARGO_HOME|BR2_JLEVEL|OMP_NUM_THREADS|CARGO_BUILD_JOBS|WGETRC)=' | sort
```

## 5. Record how git.kernel.org answers Buildroot's download URL

```bash
cd "$PROJECT_ROOT/build/downloads"
curl -sS -L --max-time 60 -D cgit-headers.txt https://git.kernel.org/torvalds/t/linux-6.3-rc4.tar.gz | head -c 512 > cgit-first-bytes.bin || echo "(transfer ended early)"
grep -iE '^(HTTP/|content-type:|location:|server:)' cgit-headers.txt || echo "(no response headers)"
file cgit-first-bytes.bin
head -c 300 cgit-first-bytes.bin | tr -c '[:print:]\n' '.'; echo
wget --spider -t 1 -T 60 -S https://git.kernel.org/torvalds/t/linux-6.3-rc4.tar.gz 2>&1 | grep -iE '^ *(HTTP/|content-type:|location:)' || echo "(wget ended with an error; any response headers are shown above)"
```

This only records evidence for the review: the HTTP status, content type, and first bytes that git.kernel.org returns
for the URL Buildroot uses, once with `curl` and once with `wget` (the program Buildroot uses). An HTML page instead of
gzip data (for example a bot check or "Unsupported snapshot format") explains the failure of the first run. Nothing in
this step can stop the gate.

## 6. Create the Linux 6.3-rc4 tarball from kernel.org Git

```bash
cd "$PROJECT_ROOT/build/downloads"
[ -d linux-v6.3-rc4.git ] || { rm -rf linux-v6.3-rc4.git.part && GIT_TERMINAL_PROMPT=0 git clone --bare --depth 1 --branch v6.3-rc4 https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git linux-v6.3-rc4.git.part && mv linux-v6.3-rc4.git.part linux-v6.3-rc4.git; }
git -C linux-v6.3-rc4.git log -1 --format='%H %cI %s' v6.3-rc4
git -C linux-v6.3-rc4.git archive --format=tar.gz --prefix=linux-6.3-rc4/ -o "$PROJECT_ROOT/build/downloads/linux-6.3-rc4.tar.gz" v6.3-rc4
ls -l linux-6.3-rc4.tar.gz
sha256sum linux-6.3-rc4.tar.gz
```

A shallow clone downloads only the tagged commit (about 0.2-0.3 GB). `git archive --prefix=linux-6.3-rc4/` creates the
same kind of archive that cgit serves as a snapshot: the tree of the tag, with the commit ID stored in the archive header.
The clone goes to a `.part` directory first, so an interrupted clone is never mistaken for a complete one on a re-run.

## 7. Verify the tarball against kernel.org and GitHub

```bash
KORG=$(GIT_TERMINAL_PROMPT=0 git ls-remote --tags https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git | awk '$2=="refs/tags/v6.3-rc4^{}" {print $1}')
GITHUB=$(GIT_TERMINAL_PROMPT=0 git ls-remote --tags https://github.com/torvalds/linux.git | awk '$2=="refs/tags/v6.3-rc4^{}" {print $1}')
TARBALL=$(git get-tar-commit-id < <(gzip -dc linux-6.3-rc4.tar.gz))
echo "kernel.org=$KORG github=$GITHUB tarball=$TARBALL"
test -n "$KORG"
test "$KORG" = "$GITHUB"
test "$KORG" = "$TARBALL"
```

Three independent values must be equal: the commit that tag `v6.3-rc4` points to on kernel.org, the same on the GitHub
mirror of Linus Torvalds' tree, and the commit ID stored inside the tarball (`git get-tar-commit-id`). If any differs,
the gate stops. The tarball's own SHA-256 can differ between Git versions, so the commit ID is the value to compare.

## 8. Place the tarball where Buildroot looks before downloading

```bash
mkdir -p "$BR2_DL_DIR/linux"
cp linux-6.3-rc4.tar.gz "$BR2_DL_DIR/linux/linux-6.3-rc4.tar.gz"
sha256sum "$BR2_DL_DIR/linux/linux-6.3-rc4.tar.gz"
```

Buildroot uses a file that already exists in its download directory instead of downloading it. Buildroot has no hash for
a custom kernel version (G05b review F5), so the commit check in step 7 is the verification of this file. The
confidential VM's Buildroot (G11) uses the same file.

## 9. Build the hypervisor image with the upstream Makefile

```bash
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
date -u
make -j2 hypervisor
date -u
```

This is the upstream procedure, with patch 0001: `hypervisor/Makefile` copies the Buildroot configuration into
`$ACE_DIR/hypervisor/buildroot`, points it at the repository's overlay, kernel configuration, and patch directory, and
runs Buildroot with `BR2_JLEVEL=2`. The echoed recipe in the log shows the value used. It is skipped when
`images/rootfs.ext2` already exists (re-run).

## 10. Verify the images and the patches Buildroot applied

```bash
BR="$ACE_DIR/hypervisor/buildroot"
ls -l "$BR/images"
sha256sum "$BR/images/Image" "$BR/images/rootfs.ext2"
file "$BR/images/Image"
ls "$BR/build" | grep -E '^(linux|qemu|busybox|dropbear|openssh|sshpass)-'
cat "$BR"/build/linux-[0-9]*/.applied_patches_list
cat "$BR"/build/qemu-[0-9]*/.applied_patches_list
grep -E '^CONFIG_(RISCV_COVE[A-Z_]*|KVM)=' "$BR"/build/linux-[0-9]*/.config
ls -l "$BR/target/usr/bin/qemu-system-riscv64"
```

| Check | Why |
|---|---|
| SHA-256 of `Image` and `rootfs.ext2` | E2 for the hypervisor kernel and root file system |
| Package directory names | the exact versions Buildroot built (Linux, nested QEMU, SSH tools) |
| `.applied_patches_list` of Linux and QEMU | Buildroot writes every patch it applied; the QEMU list must contain `cove.patch` (G05b review F6) |
| `CONFIG_RISCV_COVE*`, `CONFIG_KVM` | the kernel was configured with CoVE support and KVM (needed for E4) |
| nested `qemu-system-riscv64` in the target | the program that starts the confidential VM inside the hypervisor |

## 11. Record the toolchain Buildroot used and the downloaded sources

```bash
ls "$BR/build" | grep -E '^toolchain'
"$(ls "$BR"/host/bin/*-linux-gnu-gcc | head -n 1)" --version
ls "$BR2_DL_DIR"
find "$BR2_DL_DIR" -mindepth 2 -maxdepth 2 -type f -exec sha256sum {} + | sort -k 2
du -sh "$BR2_DL_DIR" "$ACE_DIR/hypervisor"
```

The first two lines record which external toolchain Buildroot used and its compiler version (G09 first-run review:
Buildroot uses Bootlin's toolchain, not the one from G06). Then every source archive in the download directory, with its
SHA-256 (E1), including the Bootlin toolchain and the Linux tarball from step 6.

## 12. Check the upstream tree and the project

```bash
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
git status --short
git -C hypervisor/buildroot status --short
cd "$PROJECT_ROOT"
git status --short
free -h
df -h "$PROJECT_ROOT"
```

Expected: the upstream checkout still shows only the 5 patched files; the Buildroot submodule is clean (its output and
downloads are outside it); the project shows only the two new G09 files.

## 13. Run all steps with logging

```bash
bash scripts/G09_hypervisor.sh
```

On the first run of this revision, use the downloaded copy: `bash ~/download/G09_hypervisor.sh`.
The script stops after step 1, 2, 3, 4, 6, 7, 8, or 9 if a check failed, and still seals the log.
After a failed Buildroot build, running the script again starts the Buildroot build from the beginning:
when `images/rootfs.ext2` does not exist, `hypervisor/Makefile:39` deletes `$ACE_DIR/hypervisor/buildroot`.
The downloads in `build/dl` and the Linux clone in `build/downloads` are kept and reused.
