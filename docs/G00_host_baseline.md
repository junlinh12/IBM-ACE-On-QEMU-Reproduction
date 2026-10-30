# G00: Host Baseline

This gate records the state of the host PC before anything is installed or built.
Every command below is **read-only**: nothing is installed, cloned, built, or stopped.

The same commands are run, with logging, by [`scripts/G00_host_baseline.sh`](../scripts/G00_host_baseline.sh).
You can either run the script (recommended, it keeps evidence) or copy the commands one by one.

Reference environment: Ubuntu 24.04 LTS, x86_64.
Upstream minimum for building ACE: 4 CPU cores, 4 GB RAM, 50 GB free disk.

Set the project path first (used in step 3):

```bash
PROJECT_ROOT=~/projects/IBM-ACE-On-QEMU-Reproduction
mkdir -p "$PROJECT_ROOT"
```

## 1. Check the operating system

```bash
cat /etc/os-release
uname -srm
```

Expected: `VERSION_ID="24.04"` and architecture `x86_64`.

## 2. Check CPU and memory

```bash
nproc
lscpu
free -h
grep -E '^(MemTotal|MemAvailable|SwapTotal):' /proc/meminfo
swapon --show
```

Expected: `nproc` is 4 or more, and `MemTotal` is 4 GB (4194304 kB) or more.
`MemAvailable` shows how much memory is free right now for the build.

## 3. Check free disk space and inodes

```bash
df -h "$PROJECT_ROOT"
df -B1 --output=avail,iavail "$PROJECT_ROOT"
```

Expected: at least 50 GB available (100 GB recommended, to leave room for rebuilds and logs).

## 4. Check host developer tools

```bash
git --version
make --version
gcc --version
g++ --version
clang --version
python3 --version
ninja --version
curl --version
wget --version
```

Expected: every command prints a version. `command not found` means the tool is installed in G03.

## 5. Check the Rust toolchain

```bash
rustup --version
rustup toolchain list
rustup target list --installed
rustc --version
cargo --version
```

Expected before G04: Rust may be absent. The exact nightly version is taken from
`rust-toolchain.toml` of the pinned ACE commit in G04, not from this step.

## 6. Check tools that ACE builds itself (absence is expected)

```bash
command -v qemu-system-riscv64 || echo "qemu-system-riscv64: not on host"
command -v riscv64-unknown-linux-gnu-gcc || echo "riscv64-unknown-linux-gnu-gcc: not on host"
```

ACE builds its own QEMU (`make emulator`) and RISC-V GNU toolchain (`make devtools`).
If a host copy exists, it is noted so the two are not confused later.

## 7. Check apt packages required by ACE

```bash
dpkg-query -W -f='${Package}  ${Status}  ${Version}\n' \
    autoconf automake autotools-dev curl python3 libmpc-dev libmpfr-dev \
    libgmp-dev gawk build-essential bison flex texinfo gperf libtool \
    patchutils bc zlib1g-dev libexpat1-dev xz-utils clang libclang-dev \
    llvm-dev git libglib2.0-dev libfdt-dev libpixman-1-dev ninja-build \
    python3-venv libslirp-dev unzip sed binutils diffutils bash patch gzip \
    bzip2 perl tar cpio rsync file findutils sshpass wget
```

Expected: `install ok installed` = present.
`not-installed` or `no packages found matching ...` = missing (installed in G03).

Note: the upstream README lists `libexpat-dev`. On Ubuntu 24.04 that is a virtual
name provided by `libexpat1-dev`, so the real package is checked here.

## 8. Check other experiments running on this host

```bash
ps -u "$(id -un)" -o pid=,comm= | grep -i qemu || echo "no QEMU processes"
ss -ltnH | awk '{print $4}' | sed 's/.*://' | sort -un
ls -l /dev/kvm || echo "/dev/kvm absent (not required: RISC-V is emulated)"
```

These record running QEMU processes and listening TCP ports, so that later gates do not
collide with other experiments on the same host. Only process names and port numbers are shown.
Host `/dev/kvm` is not needed: the RISC-V platform runs under QEMU emulation, and KVM is used
*inside* the emulated RISC-V Linux.

## 9. Check access to the upstream repository

```bash
GIT_TERMINAL_PROMPT=0 timeout 30 git ls-remote https://github.com/IBM/ACE-RISCV.git HEAD
```

Expected: one line with a 40-character commit hash followed by `HEAD`.
Nothing is downloaded; the commit is pinned later in G02.

## 10. Run all steps with logging

```bash
bash scripts/G00_host_baseline.sh
```

The script runs steps 1–9 and writes evidence to `logs/`:

| File | Content | Published |
|---|---|---|
| `G00_<UTC>_<id>.raw.log` | every command, its full output, and failed exit codes | No |
| `G00_<UTC>_<id>.input.sh` | exact copy of the script that was run | No |
| `G00_<UTC>_<id>.sha256` | SHA-256 seal of the two files above | No |
| `review/G00_<UTC>_<id>.review.log` | copy with home path, user name and host name masked | After review |

Do not run the script with `sudo`; it refuses to run as root.

## 11. Reference host output

Reference run `G00_20261030T122505Z_7St35c` (masked review log). Judgement: **PASS**.

| Item | Reference host | Requirement |
|---|---|---|
| OS | Ubuntu 24.04.5 LTS, kernel 7.0.0-38-generic, x86_64 | Ubuntu 24.04, x86_64 |
| CPU | Intel Core Ultra 7 265K, 20 cores | 4 cores or more |
| Memory | 30.7 GiB total, 14.8 GiB available at audit time, 8 GiB swap | 4 GB or more |
| Disk | 479.5 GiB free, 57.3 M free inodes | 50 GB or more (100 GB recommended) |
| Host tools | git 2.43.0, GNU Make 4.3, gcc/g++ 13.3.0, clang 18.1.3, Python 3.12.3, ninja 1.11.1, curl 8.5.0, wget 1.21.4 | all present |
| Rust | rustup 1.29.1, stable 1.98.1 as default | pinned nightly is added in G04 |
| ACE-built tools | a distribution `qemu-system-riscv64` exists in `/usr/bin`; no RISC-V GNU toolchain | ACE uses its own builds |
| apt packages | 45 of 46 present; `llvm-dev` missing | resolved in G02/G03 |
| Upstream HEAD | `1ebdebf4cacc04fcb83191053b4e979cbcdcb2d6` (checked 2026-10-30) | pinned in G02 |

Process and port details are kept in the private review log only.

The reference run used revision 1 of the script (SHA-256 `d5c9647b...`), which differs from the
current script only in the log folder name (`Project Logs/` instead of `logs/`). The folder was
renamed in G01, and the exact script that was run is kept, sealed, in `logs/` as the `.input.sh` file.
