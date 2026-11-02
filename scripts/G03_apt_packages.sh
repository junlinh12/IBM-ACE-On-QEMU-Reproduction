#!/usr/bin/env bash
# =============================================================================
#  IBM-ACE-On-QEMU-Reproduction
#  G03 : Install the missing Ubuntu 24.04 package (llvm-dev) required by the upstream CI
#
#  Steps 1-7 below are plain Linux commands, identical to docs/G03_apt_packages.md.
#  Uses sudo ONLY for "apt-get update" and "apt-get install -y llvm-dev".
#  Stops before installing if the simulation shows any package would be removed or upgraded.
#  One local commit is made for the reviewed G02 work. Nothing is built or pushed.
#
#  Before running, put these five files in ~/download:
#    G03_apt_packages.sh   G03_apt_packages.md   G02_review.md
#    SOURCE_PROVENANCE.md  PROJECT_CHARTER.md
#
#  Usage :  bash ~/download/G03_apt_packages.sh     (do not use sudo; it asks when needed)
#  Upload:  logs/review/G03_*.review.log   (masked copy)
# =============================================================================

# ---------------- Logging harness: start (not part of the procedure) --------
set -u -o pipefail
umask 077                                   # evidence is readable by owner only
export LC_ALL=C                             # English, stable command output

if [ "$(id -u)" -eq 0 ]; then echo "Do not run as root or with sudo." >&2; exit 2; fi

PROJECT_ROOT="$HOME/projects/IBM-ACE-On-QEMU-Reproduction"
DOWNLOAD_DIR="$HOME/download"
LOG_DIR="$PROJECT_ROOT/logs"
if [ ! -d "$LOG_DIR/review" ] || [ ! -d "$PROJECT_ROOT/.git" ]; then
    echo "Project not prepared. Run G00 and G01 first." >&2; exit 2
fi
for p in "$PROJECT_ROOT" "$LOG_DIR" "$DOWNLOAD_DIR"; do
    if [ -L "$p" ]; then echo "Symbolic link at $p; check manually." >&2; exit 2; fi
done

RAW="$(mktemp "$LOG_DIR/G03_$(date -u +%Y%m%dT%H%M%SZ)_XXXXXX.raw.log")" || exit 2
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

finish() {                                  # summary, seal, masked copy
    { set +x; } 2>/dev/null
    trap - ERR
    FAILED="$(grep -c '^### FAILED:' "$RAW")"
    printf '\n===== SUMMARY =====\nfailed_commands=%s  %s\n' "$FAILED" "$1"
    exec 1>&3 2>&4
    ( cd "$LOG_DIR" && sha256sum "$RUN_ID.raw.log" "$RUN_ID.input.sh" > "$RUN_ID.sha256" \
      && sha256sum -c --quiet "$RUN_ID.sha256" ) || { echo "Seal failed." >&2; exit 2; }
    chmod 400 "$RAW" "$LOG_DIR/$RUN_ID.input.sh" "$LOG_DIR/$RUN_ID.sha256"
    esc() { printf '%s' "$1" | sed 's/[][\.*^$|/]/\\&/g'; }
    local user_name host_name review mask
    user_name="$(id -un)"
    host_name="$(hostname 2>/dev/null || echo unknown-host)"
    review="$LOG_DIR/review/$RUN_ID.review.log"
    {
        sed -e "s|$(esc "$HOME")|~|g" \
            -e "s|\<$(esc "$user_name")\>|<user>|g" \
            -e "s|\<$(esc "$host_name")\>|<host>|g" "$RAW"
        echo "# masked_from_raw_sha256=$(sha256sum "$RAW" | cut -d' ' -f1)"
    } > "$review"
    chmod 400 "$review"
    if grep -qF "$HOME" "$review" || grep -qwF -e "$user_name" -e "$host_name" "$review"; then
        mask="WARNING - personal strings remain, do not upload"
    else
        mask="OK"
    fi
    echo
    echo "Result          : $1"
    echo "Failed commands : $FAILED"
    echo "Mask check      : $mask"
    echo "Upload          : logs/review/$RUN_ID.review.log"
    echo "Keep local      : logs/$RUN_ID.raw.log"
}

stop_if_failed() {                          # stop the gate if any command failed so far
    { set +x; } 2>/dev/null
    if grep -q '^### FAILED:' "$RAW"; then
        printf '  STOPPED: a required check failed\n' >&3
        finish "STOPPED at: $1"
        exit 1
    fi
    set -x
}

echo "# G03 Apt Packages | run=$RUN_ID | input_sha256=$(sha256sum "$LOG_DIR/$RUN_ID.input.sh" | cut -d' ' -f1)"
echo "# previous gate: G02 PASS (see logs/review/G02_review.md)"
printf 'G03 Apt Packages (%s)\n' "$RUN_ID" >&3
set -x
# ---------------- Logging harness: end ---------------------------------------


section "1. Verify the downloaded files and all sealed evidence"
cd "$DOWNLOAD_DIR"
sha256sum G03_apt_packages.sh G03_apt_packages.md
echo "4453f6b6023b41698da41f736be243034eea50bfbcea5f6971cbe3969a83c302  G02_review.md" | sha256sum -c -
echo "7577477ac34df4a2ed351fc0f1c1fe14ea3f3d888a6f2d337ffeccd845d783d8  SOURCE_PROVENANCE.md" | sha256sum -c -
echo "fb577408376877e4c5f1b88b9e4055763a3babc6c548d43a78bd6f9f88b1fedf  PROJECT_CHARTER.md" | sha256sum -c -
cd "$PROJECT_ROOT/logs"
sha256sum -c *.sha256
stop_if_failed "step 1"

section "2. Commit the reviewed G02 work (local only, UTC)"
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
stop_if_failed "step 2"

section "3. Check the packages before installing"
apt-cache policy llvm-dev clang libclang-dev

section "4. Refresh the package lists and simulate the install (sudo)"
date -u
sudo apt-get update
apt-get -s install llvm-dev
apt-get -s install llvm-dev | awk '/^Remv /{r++} /^Inst [^ ]+ \[/{u++} END{printf "remove=%d upgrade=%d\n", r, u; exit (r+u)>0}'
stop_if_failed "step 4"

section "5. Install llvm-dev (sudo)"
sudo apt-get install -y llvm-dev
date -u
stop_if_failed "step 5"

section "6. Verify every package required by the upstream CI"
dpkg-query -W -f='${Package}  ${Status}  ${Version}\n' \
    autoconf automake autotools-dev curl python3 libmpc-dev libmpfr-dev \
    libgmp-dev gawk build-essential bison flex texinfo gperf libtool \
    patchutils bc zlib1g-dev libexpat1-dev xz-utils clang libclang-dev \
    llvm-dev git libglib2.0-dev libfdt-dev libpixman-1-dev ninja-build \
    python3-venv libslirp-dev unzip sed binutils diffutils bash patch gzip \
    bzip2 perl tar cpio rsync file findutils sshpass wget
tail -n 15 /var/log/apt/history.log

section "7. Check the project repository"
cd "$PROJECT_ROOT"
git status --short
git log --format='%h  %aI  %s'


# ---------------- Logging harness: finish (not part of the procedure) -------
finish "completed"
