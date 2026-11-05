# G16a: Publication Audit (read-only)

Before anything is published, this gate lists every file that Git would publish and every commit in the history, and searches both
for personal and host information, keys and tokens, and local times (charter 4.4, success criterion E9). It also scans the evidence
in `logs/review/` that is a candidate for publication, and records the licenses involved. It changes nothing apart from the local
commit of the reviewed G15b work; the fixes are made in G16b, after the owner's decisions on the license, the scope of the published
evidence, and the GitHub repository.

Previous gate: **G15b PASS** (see `logs/review/G15b_review.md`).

The same commands are run, with logging, by [`scripts/G16a_publication_audit.sh`](../scripts/G16a_publication_audit.sh).

**Personal strings are never written into the published files.** The user name, the host name, and the home path are searched for
with `$(id -un)`, `$(hostname)`, and `$HOME`, read at run time. They appear in the private raw log only; the review copy masks them.

Set the paths first:

```bash
PROJECT_ROOT=~/projects/IBM-ACE-On-QEMU-Reproduction
DOWNLOAD_DIR=~/download
```

## 1. Verify the downloaded files and all sealed evidence

```bash
cd "$DOWNLOAD_DIR"
sha256sum G16a_publication_audit.sh G16a_publication_audit.md
echo "7ccc20622641a34be2ebb251d498bd8b6dbab03d86b40e1bdae76d9a9ff24417  G15b_review.md" | sha256sum -c -
cd "$PROJECT_ROOT/logs"
sha256sum -c *.sha256
```

Expected: every line ends with `OK`. If any check fails, stop.

## 2. Commit the reviewed G15b work (local only, UTC)

```bash
cd "$PROJECT_ROOT"
cp "$DOWNLOAD_DIR/G15b_review.md" logs/review/
git add scripts/G15b_negative_control.sh docs/G15b_negative_control.md
git status --short
git diff --cached --quiet || TZ=UTC0 git commit -m "G15b: negative control of the local attestation"
git log -1 --format='%h  %aI  %an <%ae>  %s'
cp "$DOWNLOAD_DIR/G16a_publication_audit.sh" scripts/
cp "$DOWNLOAD_DIR/G16a_publication_audit.md" docs/
```

## 3. List what Git would publish

```bash
cd "$PROJECT_ROOT"
git ls-files | sort
git ls-files | wc -l
git ls-files -z | xargs -0 du -ch | tail -n 1
git status --short
```

Only tracked files are published. `upstream/`, `build/`, and everything in `logs/` except `logs/public/` are ignored (G01).

## 4. Record the identity and dates of every commit

```bash
git log --reverse --format='%h | %an <%ae> | %aI | %cn <%ce> | %cI | %s'
git log --format='%ae%n%ce' | sort | uniq -c
git log --format='%aI%n%cI' | grep -v '+00:00$' | sort | uniq -c || echo "(every commit date is in UTC)"
```

Every author and committer address must be the GitHub no-reply address. The last line lists every commit date that is not in UTC;
the root commit is expected here with a non-UTC offset (G02 review F8).

## 5. Search the whole history for personal and host strings

```bash
git grep -l -I -w -F -e "$(id -un)" $(git rev-list --all) || echo "(user name: not found)"
git grep -l -I -w -F -e "$(hostname)" $(git rev-list --all) || echo "(host name: not found)"
git grep -l -I -F -e "$HOME" $(git rev-list --all) || echo "(home path: not found)"
git grep -l -I -e '/home/' $(git rev-list --all) || echo "(/home/: not found)"
git grep -l -I -F -e "$(env -u TZ date +%:z)" $(git rev-list --all) || echo "(local offset: not found)"
git log --all --format='%B' | grep -c -w -F -e "$(id -un)" -e "$(hostname)" || echo "(not found in commit messages)"
```

The user name and the host name are matched as whole words (`-w`), so that a short name does not match inside other words.
`git grep ... $(git rev-list --all)` searches every committed version of every file, not only the current one: a string removed later
would still be published with the history. Each line prints the commits and files where it occurs, or "not found".

## 6. Search the published files for content that needs a person to judge

```bash
git grep -n -I -E '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' HEAD | cut -c1-200 || echo "(no IPv4 address)"
git grep -n -I -E '\b([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}\b' HEAD | cut -c1-200 || echo "(no MAC address)"
git grep -n -I -E 'BEGIN [A-Z ]*PRIVATE KEY|ghp_[A-Za-z0-9]{20,}|github_pat_|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]+|passw' HEAD | cut -c1-200 || echo "(no key, token, or password)"
git grep -h -I -o -E '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' HEAD | sort | uniq -c || echo "(no e-mail address)"
```

These find candidates rather than proven leaks: for example `127.0.0.1` and the emulated network `192.168.100.0/24` are expected, and so
is the upstream guest password `passwd`, which is public in the upstream repository. The review classifies every hit.

## 7. Scan the candidate evidence in logs/review

```bash
ls -l logs/review
grep -l -w -F -e "$(id -un)" -e "$(hostname)" logs/review/* || echo "(no user name or host name in logs/review)"
grep -l -F -e "$HOME" logs/review/* || echo "(no home path in logs/review)"
grep -c -F "$(env -u TZ date +%:z)" logs/review/* | grep -v ':0$' || echo "(no local offset in logs/review)"
grep -c -E ' [A-Z][a-z]{2} +[0-9]{1,2} [0-9]{2}:[0-9]{2} ' logs/review/* | grep -v ':0$' || echo "(no ls-style local time in logs/review)"
grep -n -E 'Requested-By|Start-Date|End-Date' logs/review/* | cut -c1-160 || echo "(no apt history line)"
grep -l -E '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' logs/review/* || echo "(no IPv4 address in logs/review)"
```

`logs/review/` holds the masked review logs, the gate reviews, and the checkpoints. None of it is published yet; this step finds what
would have to be cleaned or left out if some of it is published: local times printed before the harness used UTC (G08, SAFETY_AUDIT
A17), the apt history of G03 (G03 review F3), and addresses.

## 8. Record the licenses involved

```bash
head -n 3 upstream/ACE-RISCV/LICENSE
git -C upstream/ACE-RISCV ls-files | grep -i -E '(^|/)(license|copying|notice)[^/]*$' || echo "(no further license file)"
grep -H -m 1 'SPDX-License-Identifier' upstream/ACE-RISCV/tools/ace_run_hypervisor.sh upstream/ACE-RISCV/tools/common.sh upstream/ACE-RISCV/hypervisor/Makefile upstream/ACE-RISCV/security-monitor/Makefile upstream/ACE-RISCV/confidential-vms/linux_vm/Makefile || echo "(no SPDX identifier in the patched files)"
ls LICENSE* NOTICE* README* 2>/dev/null || echo "(no license, notice, or readme file in the project yet)"
```

The project publishes patches to IBM's files (`patches/`) and documents that quote IBM's sources, so the upstream license applies to
those parts. The last line shows that the project itself has no license or README yet; both are added in G16b.

## 9. Record the manifest of the publishable files

```bash
git ls-files -z | xargs -0 sha256sum
```

The SHA-256 of every file that would be published, as audited. G16b and G17 compare against this list.

## 10. Check the project

```bash
git status --short
git log --oneline | wc -l
```

## 11. Run all steps with logging

```bash
bash scripts/G16a_publication_audit.sh
```

On the first run, use the downloaded copy: `bash ~/download/G16a_publication_audit.sh`.
The script stops after step 1 or 2 if a check failed. The search steps only record what they find; the review decides.
