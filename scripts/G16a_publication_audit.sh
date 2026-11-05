#!/usr/bin/env bash
# =============================================================================
#  IBM-ACE-On-QEMU-Reproduction
#  G16a : Publication audit (read-only): what Git would publish, and the whole Git history
#
#  Steps 1-10 below are plain Linux commands, identical to docs/G16a_publication_audit.md.
#  Lists every file Git would publish, every commit's identity and dates, and searches the whole
#  history and the candidate evidence in logs/review for personal and host information, keys, and
#  local times. The user name, host name, and home path are read at run time; they are never
#  written into this script. Nothing is changed except one local commit of the reviewed G15b work.
#  No sudo. Nothing is pushed.
#
#  Before running, put these three files in ~/download:
#    G16a_publication_audit.sh   G16a_publication_audit.md   G15b_review.md
#
#  Usage :  bash ~/download/G16a_publication_audit.sh        (do not use sudo)
#  Upload:  logs/review/G16a_*.review.log   (masked copy)
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

RAW="$(mktemp "$LOG_DIR/G16a_$(date -u +%Y%m%dT%H%M%SZ)_XXXXXX.raw.log")" || exit 2
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
    FINISHED=1
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

# Seal the log on every exit, also when the shell stops unexpectedly (for example an unset variable).
trap '{ rc=$?; set +x; } 2>/dev/null; [ -n "${FINISHED:-}" ] || finish "ABORTED: shell exited with status $rc"' EXIT

echo "# G16a Publication Audit | run=$RUN_ID | input_sha256=$(sha256sum "$LOG_DIR/$RUN_ID.input.sh" | cut -d' ' -f1)"
echo "# previous gate: G15b PASS (see logs/review/G15b_review.md)"
printf 'G16a Publication Audit (%s)\n' "$RUN_ID" >&3
set -x
# ---------------- Logging harness: end ---------------------------------------


section "1. Verify the downloaded files and all sealed evidence"
cd "$DOWNLOAD_DIR"
sha256sum G16a_publication_audit.sh G16a_publication_audit.md
echo "7ccc20622641a34be2ebb251d498bd8b6dbab03d86b40e1bdae76d9a9ff24417  G15b_review.md" | sha256sum -c -
cd "$PROJECT_ROOT/logs"
sha256sum -c *.sha256
stop_if_failed "step 1"

section "2. Commit the reviewed G15b work (local only, UTC)"
cd "$PROJECT_ROOT"
cp "$DOWNLOAD_DIR/G15b_review.md" logs/review/
git add scripts/G15b_negative_control.sh docs/G15b_negative_control.md
git status --short
git diff --cached --quiet || TZ=UTC0 git commit -m "G15b: negative control of the local attestation"
git log -1 --format='%h  %aI  %an <%ae>  %s'
cp "$DOWNLOAD_DIR/G16a_publication_audit.sh" scripts/
cp "$DOWNLOAD_DIR/G16a_publication_audit.md" docs/
stop_if_failed "step 2"

section "3. List what Git would publish"
cd "$PROJECT_ROOT"
git ls-files | sort
git ls-files | wc -l
git ls-files -z | xargs -0 du -ch | tail -n 1
git status --short

section "4. Record the identity and dates of every commit"
git log --reverse --format='%h | %an <%ae> | %aI | %cn <%ce> | %cI | %s'
git log --format='%ae%n%ce' | sort | uniq -c
git log --format='%aI%n%cI' | grep -v '+00:00$' | sort | uniq -c || echo "(every commit date is in UTC)"

section "5. Search the whole history for personal and host strings"
git grep -l -I -w -F -e "$(id -un)" $(git rev-list --all) || echo "(user name: not found)"
git grep -l -I -w -F -e "$(hostname)" $(git rev-list --all) || echo "(host name: not found)"
git grep -l -I -F -e "$HOME" $(git rev-list --all) || echo "(home path: not found)"
git grep -l -I -e '/home/' $(git rev-list --all) || echo "(/home/: not found)"
git grep -l -I -F -e "$(env -u TZ date +%:z)" $(git rev-list --all) || echo "(local offset: not found)"
git log --all --format='%B' | grep -c -w -F -e "$(id -un)" -e "$(hostname)" || echo "(not found in commit messages)"

section "6. Search the published files for content that needs a person to judge"
git grep -n -I -E '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' HEAD | cut -c1-200 || echo "(no IPv4 address)"
git grep -n -I -E '\b([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}\b' HEAD | cut -c1-200 || echo "(no MAC address)"
git grep -n -I -E 'BEGIN [A-Z ]*PRIVATE KEY|ghp_[A-Za-z0-9]{20,}|github_pat_|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]+|passw' HEAD | cut -c1-200 || echo "(no key, token, or password)"
git grep -h -I -o -E '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' HEAD | sort | uniq -c || echo "(no e-mail address)"

section "7. Scan the candidate evidence in logs/review"
ls -l logs/review
grep -l -w -F -e "$(id -un)" -e "$(hostname)" logs/review/* || echo "(no user name or host name in logs/review)"
grep -l -F -e "$HOME" logs/review/* || echo "(no home path in logs/review)"
grep -c -F "$(env -u TZ date +%:z)" logs/review/* | grep -v ':0$' || echo "(no local offset in logs/review)"
grep -c -E ' [A-Z][a-z]{2} +[0-9]{1,2} [0-9]{2}:[0-9]{2} ' logs/review/* | grep -v ':0$' || echo "(no ls-style local time in logs/review)"
grep -n -E 'Requested-By|Start-Date|End-Date' logs/review/* | cut -c1-160 || echo "(no apt history line)"
grep -l -E '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' logs/review/* || echo "(no IPv4 address in logs/review)"

section "8. Record the licenses involved"
head -n 3 upstream/ACE-RISCV/LICENSE
git -C upstream/ACE-RISCV ls-files | grep -i -E '(^|/)(license|copying|notice)[^/]*$' || echo "(no further license file)"
grep -H -m 1 'SPDX-License-Identifier' upstream/ACE-RISCV/tools/ace_run_hypervisor.sh upstream/ACE-RISCV/tools/common.sh upstream/ACE-RISCV/hypervisor/Makefile upstream/ACE-RISCV/security-monitor/Makefile upstream/ACE-RISCV/confidential-vms/linux_vm/Makefile || echo "(no SPDX identifier in the patched files)"
ls LICENSE* NOTICE* README* 2>/dev/null || echo "(no license, notice, or readme file in the project yet)"

section "9. Record the manifest of the publishable files"
git ls-files -z | xargs -0 sha256sum

section "10. Check the project"
git status --short
git log --oneline | wc -l


# ---------------- Logging harness: finish (not part of the procedure) -------
finish "completed"
