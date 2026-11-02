#!/usr/bin/env bash
# =============================================================================
#  IBM-ACE-On-QEMU-Reproduction
#  G09 : Build the RISC-V Linux hypervisor image with Buildroot (make hypervisor)
#        Revision 2: the Linux 6.3-rc4 source is built from kernel.org Git and verified,
#        because Buildroot's download of the cgit snapshot failed (first run BLOCKED).
#
#  Steps 1-12 below are plain Linux commands, identical to docs/G09_hypervisor.md.
#  Uses the build settings in scripts/build_env.sh (docs/SAFETY_AUDIT.md).
#  Stops before building if less than 4 GiB of memory or 30 GB of disk is available.
#  No sudo. Nothing is pushed. No upstream file is modified.
#
#  Before running, put these three files in ~/download:
#    G09_hypervisor.sh (revision 2)   G09_hypervisor.md (revision 2)   G09_run1_review.md
#
#  Usage :  bash ~/download/G09_hypervisor.sh        (do not use sudo)
#           Recommended: run it inside tmux, because the build takes a long time.
#  Upload:  logs/review/G09_*.review.log   (masked copy)
# =============================================================================

# ---------------- Logging harness: start (not part of the procedure) --------
set -u -o pipefail
umask 077                                   # evidence is readable by owner only
export LC_ALL=C                             # English, stable command output
export TZ=UTC0                              # every printed time in UTC (SAFETY_AUDIT A17)

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

RAW="$(mktemp "$LOG_DIR/G09_$(date -u +%Y%m%dT%H%M%SZ)_XXXXXX.raw.log")" || exit 2
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

echo "# G09 Hypervisor | run=$RUN_ID | input_sha256=$(sha256sum "$LOG_DIR/$RUN_ID.input.sh" | cut -d' ' -f1)"
echo "# previous gate: G08 PASS; G09 first run BLOCKED (see logs/review/G09_run1_review.md)"
printf 'G09 Hypervisor (%s)\n' "$RUN_ID" >&3
set -x
# ---------------- Logging harness: end ---------------------------------------


section "1. Verify the downloaded files and all sealed evidence"
cd "$DOWNLOAD_DIR"
sha256sum G09_hypervisor.sh G09_hypervisor.md
echo "031f6025b0755cf1705af33934f5fe1bf886c51808d8545aef82191a2aed4a4d  G08_review.md" | sha256sum -c -
echo "e192c293a98ef41d3476579bb03e9be1a250c348aecf31641236fa741e1e39c7  G09_run1_review.md" | sha256sum -c -
cd "$PROJECT_ROOT/logs"
sha256sum -c *.sha256
stop_if_failed "step 1"

section "2. Commit the reviewed G08 work (local only, UTC)"
cd "$PROJECT_ROOT"
cp "$DOWNLOAD_DIR/G08_review.md" logs/review/
cp "$DOWNLOAD_DIR/G09_run1_review.md" logs/review/
git add scripts/G08_emulator.sh docs/G08_emulator.md
git status --short
git diff --cached --quiet || TZ=UTC0 git commit -m "G08: QEMU 8.2.1 for the emulated platform (make emulator)"
git log -1 --format='%h  %aI  %an <%ae>  %s'
cp "$DOWNLOAD_DIR/G09_hypervisor.sh" scripts/
cp "$DOWNLOAD_DIR/G09_hypervisor.md" docs/
stop_if_failed "step 2"

section "3. Record the host and source state, and check memory and disk"
uname -r
free -h
df -h "$PROJECT_ROOT"
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
git status --short
test "$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)" -ge 4194304
test "$(df -BG --output=avail "$PROJECT_ROOT" | tail -n 1 | tr -dc '0-9')" -ge 30
stop_if_failed "step 3"

section "4. Set the build environment"
source "$PROJECT_ROOT/scripts/build_env.sh"
env | grep -E '^(ACE_DIR|QEMU_SOURCE_DIR|BR2_DL_DIR|CARGO_HOME|BR2_JLEVEL|OMP_NUM_THREADS|CARGO_BUILD_JOBS|WGETRC)=' | sort
stop_if_failed "step 4"

section "5. Record how git.kernel.org answers Buildroot's download URL"
cd "$PROJECT_ROOT/build/downloads"
curl -sS -L --max-time 60 -D cgit-headers.txt https://git.kernel.org/torvalds/t/linux-6.3-rc4.tar.gz | head -c 512 > cgit-first-bytes.bin || echo "(transfer ended early)"
grep -iE '^(HTTP/|content-type:|location:|server:)' cgit-headers.txt || echo "(no response headers)"
file cgit-first-bytes.bin
head -c 300 cgit-first-bytes.bin | tr -c '[:print:]\n' '.'; echo
wget --spider -t 1 -T 60 -S https://git.kernel.org/torvalds/t/linux-6.3-rc4.tar.gz 2>&1 | grep -iE '^ *(HTTP/|content-type:|location:)' || echo "(wget ended with an error; any response headers are shown above)"

section "6. Create the Linux 6.3-rc4 tarball from kernel.org Git"
cd "$PROJECT_ROOT/build/downloads"
[ -d linux-v6.3-rc4.git ] || { rm -rf linux-v6.3-rc4.git.part && GIT_TERMINAL_PROMPT=0 git clone --bare --depth 1 --branch v6.3-rc4 https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git linux-v6.3-rc4.git.part && mv linux-v6.3-rc4.git.part linux-v6.3-rc4.git; }
git -C linux-v6.3-rc4.git log -1 --format='%H %cI %s' v6.3-rc4
git -C linux-v6.3-rc4.git archive --format=tar.gz --prefix=linux-6.3-rc4/ -o "$PROJECT_ROOT/build/downloads/linux-6.3-rc4.tar.gz" v6.3-rc4
ls -l linux-6.3-rc4.tar.gz
sha256sum linux-6.3-rc4.tar.gz
stop_if_failed "step 6"

section "7. Verify the tarball against kernel.org and GitHub"
KORG=$(GIT_TERMINAL_PROMPT=0 git ls-remote --tags https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git | awk '$2=="refs/tags/v6.3-rc4^{}" {print $1}')
GITHUB=$(GIT_TERMINAL_PROMPT=0 git ls-remote --tags https://github.com/torvalds/linux.git | awk '$2=="refs/tags/v6.3-rc4^{}" {print $1}')
TARBALL=$(git get-tar-commit-id < <(gzip -dc linux-6.3-rc4.tar.gz))
echo "kernel.org=$KORG github=$GITHUB tarball=$TARBALL"
test -n "$KORG"
test "$KORG" = "$GITHUB"
test "$KORG" = "$TARBALL"
stop_if_failed "step 7"

section "8. Place the tarball where Buildroot looks before downloading"
mkdir -p "$BR2_DL_DIR/linux"
cp linux-6.3-rc4.tar.gz "$BR2_DL_DIR/linux/linux-6.3-rc4.tar.gz"
sha256sum "$BR2_DL_DIR/linux/linux-6.3-rc4.tar.gz"
stop_if_failed "step 8"

section "9. Build the hypervisor image with the upstream Makefile"
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
date -u
make -j2 hypervisor
date -u
stop_if_failed "step 9"

section "10. Verify the images and the patches Buildroot applied"
BR="$ACE_DIR/hypervisor/buildroot"
ls -l "$BR/images"
sha256sum "$BR/images/Image" "$BR/images/rootfs.ext2"
file "$BR/images/Image"
ls "$BR/build" | grep -E '^(linux|qemu|busybox|dropbear|openssh|sshpass)-'
cat "$BR"/build/linux-[0-9]*/.applied_patches_list
cat "$BR"/build/qemu-[0-9]*/.applied_patches_list
grep -E '^CONFIG_(RISCV_COVE[A-Z_]*|KVM)=' "$BR"/build/linux-[0-9]*/.config
ls -l "$BR/target/usr/bin/qemu-system-riscv64"

section "11. Record the toolchain Buildroot used and the downloaded sources"
ls "$BR/build" | grep -E '^toolchain'
"$(ls "$BR"/host/bin/*-linux-gnu-gcc | head -n 1)" --version
ls "$BR2_DL_DIR"
find "$BR2_DL_DIR" -mindepth 2 -maxdepth 2 -type f -exec sha256sum {} + | sort -k 2
du -sh "$BR2_DL_DIR" "$ACE_DIR/hypervisor"

section "12. Check the upstream tree and the project"
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
git status --short
git -C hypervisor/buildroot status --short
cd "$PROJECT_ROOT"
git status --short
free -h
df -h "$PROJECT_ROOT"


# ---------------- Logging harness: finish (not part of the procedure) -------
finish "completed"
