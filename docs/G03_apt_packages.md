# G03: Install the Missing Ubuntu Package

This gate installs the one package that the upstream CI requires and the host lacks: `llvm-dev`
(CI step "install OpenSBI dependencies": `clang libclang-dev llvm-dev`). It first simulates the
install and stops if any installed package would be removed or upgraded, because the host is shared
with other experiments. It also commits the reviewed G02 work locally.

Previous gate: **G02 PASS** (see `logs/review/G02_review.md`).

The same commands are run, with logging, by [`scripts/G03_apt_packages.sh`](../scripts/G03_apt_packages.sh).
`sudo` is used only for `apt-get update` and `apt-get install -y llvm-dev`.

Set the paths first:

```bash
PROJECT_ROOT=~/projects/IBM-ACE-On-QEMU-Reproduction
DOWNLOAD_DIR=~/download
```

## 1. Verify the downloaded files and all sealed evidence

```bash
cd "$DOWNLOAD_DIR"
sha256sum G03_apt_packages.sh G03_apt_packages.md
echo "4453f6b6023b41698da41f736be243034eea50bfbcea5f6971cbe3969a83c302  G02_review.md" | sha256sum -c -
echo "7577477ac34df4a2ed351fc0f1c1fe14ea3f3d888a6f2d337ffeccd845d783d8  SOURCE_PROVENANCE.md" | sha256sum -c -
echo "fb577408376877e4c5f1b88b9e4055763a3babc6c548d43a78bd6f9f88b1fedf  PROJECT_CHARTER.md" | sha256sum -c -
cd "$PROJECT_ROOT/logs"
sha256sum -c *.sha256
```

Expected: every line ends with `OK`. If any check fails, stop.

## 2. Commit the reviewed G02 work (local only, UTC)

```bash
cd "$PROJECT_ROOT"
cp "$DOWNLOAD_DIR/G02_review.md" logs/review/
cp "$DOWNLOAD_DIR/PROJECT_CHARTER.md" PROJECT_CHARTER.md
cp "$DOWNLOAD_DIR/SOURCE_PROVENANCE.md" docs/
git add PROJECT_CHARTER.md docs/SOURCE_PROVENANCE.md scripts/G02_fetch_upstream.sh docs/G02_fetch_upstream.md
git status --short
git diff --cached --quiet || TZ=UTC0 git commit -m "G02: pin IBM ACE-RISCV 1ebdebf and record source provenance"
git log -2 --format='%h  %aI  %an <%ae>  %s'
git show --stat --format= HEAD
cp "$DOWNLOAD_DIR/G03_apt_packages.sh" scripts/
cp "$DOWNLOAD_DIR/G03_apt_packages.md" docs/
```

The commit contains the charter v1.2, `docs/SOURCE_PROVENANCE.md`, and the G02 script and document.
`TZ=UTC0` makes the commit date use `+00:00`, so it does not reveal the host's time zone (charter 4.4).
Expected: the new commit shows `+00:00`; the earlier root commit still shows a non-UTC offset and is normalized in G16.

## 3. Check the packages before installing

```bash
apt-cache policy llvm-dev clang libclang-dev
```

Expected: `llvm-dev` shows `Installed: (none)`; `clang` and `libclang-dev` are installed.

## 4. Refresh the package lists and simulate the install (sudo)

```bash
date -u
sudo apt-get update
apt-get -s install llvm-dev
apt-get -s install llvm-dev | awk '/^Remv /{r++} /^Inst [^ ]+ \[/{u++} END{printf "remove=%d upgrade=%d\n", r, u; exit (r+u)>0}'
```

`apt-get update` changes only the package lists, not any installed package.
`apt-get -s` is a simulation and needs no `sudo`. In its output, `Inst name (version ...)` is a new
package, `Inst name [old] (new ...)` is an upgrade, and `Remv` is a removal.
The last line counts removals and upgrades, and fails if there is any. If it fails, stop:
the install would change packages that other projects on this host may use.

## 5. Install llvm-dev (sudo)

```bash
sudo apt-get install -y llvm-dev
date -u
```

Only the packages listed as `Inst` in step 4 are installed.

## 6. Verify every package required by the upstream CI

```bash
dpkg-query -W -f='${Package}  ${Status}  ${Version}\n' \
    autoconf automake autotools-dev curl python3 libmpc-dev libmpfr-dev \
    libgmp-dev gawk build-essential bison flex texinfo gperf libtool \
    patchutils bc zlib1g-dev libexpat1-dev xz-utils clang libclang-dev \
    llvm-dev git libglib2.0-dev libfdt-dev libpixman-1-dev ninja-build \
    python3-venv libslirp-dev unzip sed binutils diffutils bash patch gzip \
    bzip2 perl tar cpio rsync file findutils sshpass wget
tail -n 15 /var/log/apt/history.log
```

Expected: all 46 packages show `install ok installed`, and the command exits with 0
(the list is the same as in G00, step 7). The apt history shows the transaction made in step 5.

## 7. Check the project repository

```bash
cd "$PROJECT_ROOT"
git status --short
git log --format='%h  %aI  %s'
```

Expected: only the two new G03 files are untracked, and there are two commits.

## 8. Run all steps with logging

```bash
bash scripts/G03_apt_packages.sh
```

On the first run, use the downloaded copy: `bash ~/download/G03_apt_packages.sh`.
Do not start it with `sudo`; it asks for the password at step 4 when needed.
The script stops after step 1, 2, 4, or 5 if a check failed, and still seals the log.
