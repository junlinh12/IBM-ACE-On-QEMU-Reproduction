#!/usr/bin/env bash
# =============================================================================
#  IBM-ACE-On-QEMU-Reproduction
#  G00 : Host Baseline (read-only)
#  Revision 2: log folder is logs/. The reference run used revision 1
#  (sha256 d5c9647b...), which differs only in the folder name "Project Logs/".
#
#  Steps 1-9 below are plain Linux commands, identical to docs/G00_host_baseline.md.
#  They only READ the host state: nothing is installed, cloned, built or stopped.
#
#  Usage :  bash G00_host_baseline.sh        (do not use sudo)
#  Upload:  logs/review/G00_*.review.log   (masked copy)
# =============================================================================

# ---------------- Logging harness: start (not part of the procedure) --------
set -u -o pipefail
umask 077                                   # evidence is readable by owner only
export LC_ALL=C                             # English, stable command output

if [ "$(id -u)" -eq 0 ]; then echo "Do not run as root or with sudo." >&2; exit 2; fi

PROJECT_ROOT="$HOME/projects/IBM-ACE-On-QEMU-Reproduction"
LOG_DIR="$PROJECT_ROOT/logs"
for p in "$PROJECT_ROOT" "$LOG_DIR"; do
    if [ -L "$p" ]; then echo "Symbolic link at $p; check manually." >&2; exit 2; fi
done
mkdir -p "$LOG_DIR/review" && chmod 700 "$LOG_DIR" "$LOG_DIR/review" || exit 2

RAW="$(mktemp "$LOG_DIR/G00_$(date -u +%Y%m%dT%H%M%SZ)_XXXXXX.raw.log")" || exit 2
RUN_ID="$(basename "$RAW" .raw.log)"
cp "${BASH_SOURCE[0]}" "$LOG_DIR/$RUN_ID.input.sh" || exit 2

exec 3>&1 4>&2                              # keep the terminal on fd 3/4
exec >>"$RAW" 2>&1                          # everything else goes to the log
PS4='$ '                                    # traced commands look like "$ cmd"
trap '{ rc=$?; set +x; } 2>/dev/null; echo "### FAILED: exit=$rc line=$LINENO"; set -x' ERR

section() {                                 # print a step title to log and terminal
    { set +x; } 2>/dev/null
    printf '\n===== %s =====\n' "$1"
    printf '  %s\n' "$1" >&3
    set -x
}

echo "# G00 Host Baseline | run=$RUN_ID | input_sha256=$(sha256sum "$LOG_DIR/$RUN_ID.input.sh" | cut -d' ' -f1)"
printf 'G00 Host Baseline (%s)\n' "$RUN_ID" >&3
set -x
# ---------------- Logging harness: end ---------------------------------------


section "1. Check the operating system"
cat /etc/os-release
uname -srm

section "2. Check CPU and memory"
nproc
lscpu
free -h
grep -E '^(MemTotal|MemAvailable|SwapTotal):' /proc/meminfo
swapon --show

section "3. Check free disk space and inodes"
df -h "$PROJECT_ROOT"
df -B1 --output=avail,iavail "$PROJECT_ROOT"

section "4. Check host developer tools"
git --version
make --version
gcc --version
g++ --version
clang --version
python3 --version
ninja --version
curl --version
wget --version

section "5. Check the Rust toolchain"
rustup --version
rustup toolchain list
rustup target list --installed
rustc --version
cargo --version

section "6. Check tools that ACE builds itself (absence is expected)"
command -v qemu-system-riscv64 || echo "qemu-system-riscv64: not on host"
command -v riscv64-unknown-linux-gnu-gcc || echo "riscv64-unknown-linux-gnu-gcc: not on host"

section "7. Check apt packages required by ACE"
dpkg-query -W -f='${Package}  ${Status}  ${Version}\n' \
    autoconf automake autotools-dev curl python3 libmpc-dev libmpfr-dev \
    libgmp-dev gawk build-essential bison flex texinfo gperf libtool \
    patchutils bc zlib1g-dev libexpat1-dev xz-utils clang libclang-dev \
    llvm-dev git libglib2.0-dev libfdt-dev libpixman-1-dev ninja-build \
    python3-venv libslirp-dev unzip sed binutils diffutils bash patch gzip \
    bzip2 perl tar cpio rsync file findutils sshpass wget

section "8. Check other experiments running on this host"
ps -u "$(id -un)" -o pid=,comm= | grep -i qemu || echo "no QEMU processes"
ss -ltnH | awk '{print $4}' | sed 's/.*://' | sort -un
ls -l /dev/kvm || echo "/dev/kvm absent (not required: RISC-V is emulated)"

section "9. Check access to the upstream repository"
GIT_TERMINAL_PROMPT=0 timeout 30 git ls-remote https://github.com/IBM/ACE-RISCV.git HEAD


# ---------------- Logging harness: finish (not part of the procedure) -------
{ set +x; } 2>/dev/null
trap - ERR
FAILED="$(grep -c '^### FAILED:' "$RAW")"
echo
echo "===== SUMMARY ====="
echo "failed_commands=$FAILED  (a missing tool counts here; judged in review)"
exec 1>&3 2>&4

# Seal: hash raw log + input script, then make them read-only.
( cd "$LOG_DIR" && sha256sum "$RUN_ID.raw.log" "$RUN_ID.input.sh" > "$RUN_ID.sha256" \
  && sha256sum -c --quiet "$RUN_ID.sha256" ) || { echo "Seal failed." >&2; exit 2; }
chmod 400 "$RAW" "$LOG_DIR/$RUN_ID.input.sh" "$LOG_DIR/$RUN_ID.sha256"

# Masked copy for review: home path anywhere; user and host names as whole words.
esc() { printf '%s' "$1" | sed 's/[][\.*^$|/]/\\&/g'; }
USER_NAME="$(id -un)"
HOST_NAME="$(hostname 2>/dev/null || echo unknown-host)"
REVIEW="$LOG_DIR/review/$RUN_ID.review.log"
{
    sed -e "s|$(esc "$HOME")|~|g" \
        -e "s|\<$(esc "$USER_NAME")\>|<user>|g" \
        -e "s|\<$(esc "$HOST_NAME")\>|<host>|g" "$RAW"
    echo "# masked_from_raw_sha256=$(sha256sum "$RAW" | cut -d' ' -f1)"
} > "$REVIEW"
chmod 400 "$REVIEW"

if grep -qF "$HOME" "$REVIEW" || grep -qwF -e "$USER_NAME" -e "$HOST_NAME" "$REVIEW"; then
    MASK="WARNING - personal strings remain, do not upload"
else
    MASK="OK"
fi

echo
echo "Failed commands : $FAILED"
echo "Mask check      : $MASK"
echo "Upload          : logs/review/$RUN_ID.review.log"
echo "Keep local      : logs/$RUN_ID.raw.log"
