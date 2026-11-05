# G18: State the Reproduced Paper in the README

The owner asked that the repository state first which paper its results reproduce. This project reproduced the implementation that
accompanies "ACE: Confidential Computing for Embedded RISC-V Systems" (<https://arxiv.org/html/2505.12995v1>, 2025-05-19), and its
functional behaviour, not the paper's hardware evaluation. Because the arXiv entry was later revised under another title, the README names
this paper by its title and its version-1 address, not by the bare arXiv number. This gate puts that statement at the top of `README.md`,
adds the G17 evidence, and pushes.

Previous gate: **G17 PASS** (see `logs/review/G17_review.md`).

The same commands are run, with logging, by [`scripts/G18_readme_paper.sh`](../scripts/G18_readme_paper.sh).

**The repository is public.** The push becomes visible as soon as it completes, so the owner reviews the revised `README.md` before running
this gate. The push is a fast-forward of the commit published in G17; the published history is not rewritten.

**A token is needed again.** If the token of G17 was deleted, create a new fine-grained token for this repository only (Contents: Read and
write, short expiration), as before. Never paste it anywhere but at git's `Password` prompt.

Set the paths first:

```bash
PROJECT_ROOT=~/projects/IBM-ACE-On-QEMU-Reproduction
DOWNLOAD_DIR=~/download
```

## 1. Verify the downloaded files and all sealed evidence

```bash
cd "$DOWNLOAD_DIR"
sha256sum G18_readme_paper.sh G18_readme_paper.md
echo "78c8ff23da01ad1b58ed9670a5a82b179e1790561a9130ecab2a1aac9f5ddf97  G17_review.md" | sha256sum -c -
echo "c23c42a74fec448f91a67f4d2c48e08ef2132750e0a91562e269cd724ef4ca93  README.md" | sha256sum -c -
cd "$PROJECT_ROOT/logs"
sha256sum -c *.sha256
```

Expected: every line ends with `OK`. `README.md` is revision 2, with the statement of the reproduced paper. If any check fails, stop.

## 2. Check without logging in that GitHub still holds the commit published in G17

```bash
cd "$PROJECT_ROOT"
REPO=junlinh12/IBM-ACE-On-QEMU-Reproduction
PUBLIC_URL="https://github.com/$REPO.git"
test "$(curl -s -o /dev/null -w '%{http_code}' "https://api.github.com/repos/$REPO")" = 200
git ls-remote "$PUBLIC_URL"
test "$(git ls-remote "$PUBLIC_URL" refs/heads/main | cut -f1)" = "$(git rev-parse HEAD)"
test "$(git rev-parse HEAD)" = b11c247276c47c057014abca1c78e0c2882519d7
git status --short
```

The repository is public now, so it can be read without logging in: the API answers `200`, and `git ls-remote` on the public URL
(without a user name, so git never asks for a password) shows what GitHub holds. It must still be the commit published and verified in G17,
`b11c247...`, and the local `HEAD` must be the same commit: then nobody has changed the repository since, and the new commit will be a
fast-forward.

## 3. Commit the revised README and the sanitized G17 evidence (local only, UTC)

```bash
cp "$DOWNLOAD_DIR/G17_review.md" logs/review/
cp "$DOWNLOAD_DIR/README.md" README.md
cp "$DOWNLOAD_DIR/G18_readme_paper.sh" scripts/
cp "$DOWNLOAD_DIR/G18_readme_paper.md" docs/
PORTS="$PROJECT_ROOT/build/private/listening-ports.txt"
test -s "$PORTS"
test -z "$(grep -F -e "$(env -u TZ date +%:z)" -e "$(env -u TZ date +%z)" -e "$(timedatectl show -p Timezone --value)" README.md scripts/G18_readme_paper.sh docs/G18_readme_paper.md)"
test -z "$(grep -w -F -e "$(env -u TZ date +%Z)" -f "$PROJECT_ROOT/build/private/listening-ports-high.txt" README.md scripts/G18_readme_paper.sh docs/G18_readme_paper.md)"
rm -rf logs/public/reviews logs/public/review-logs
mkdir -p logs/public/reviews logs/public/review-logs
for f in logs/review/*.md; do scripts/sanitize_evidence.sh --ports "$PORTS" < "$f" > "logs/public/reviews/$(basename "$f")"; done
for f in logs/review/G0[0-7]*.review.log; do scripts/sanitize_evidence.sh --pre-utc --ports "$PORTS" < "$f" > "logs/public/review-logs/$(basename "$f")"; done
for f in logs/review/G0[89]*.review.log logs/review/G1*.review.log; do scripts/sanitize_evidence.sh --ports "$PORTS" < "$f" > "logs/public/review-logs/$(basename "$f")"; done
(cd logs/review && sha256sum *.md *.review.log) > logs/public/ORIGINALS.sha256
(cd logs/public && find reviews review-logs -type f | sort | xargs sha256sum) > logs/public/SHA256SUMS
git add README.md scripts/G18_readme_paper.sh docs/G18_readme_paper.md logs/public
git status --short
TZ=UTC0 git commit -q -m "G18: README states the reproduced paper and its scope; G17 evidence"
git log -1 --format='%h  %aI  %an <%ae>  %s'
git show --stat --format= HEAD
```

The revised README states, before anything else, which paper is reproduced ("ACE: Confidential Computing for Embedded RISC-V
Systems", <https://arxiv.org/html/2505.12995v1>), which implementation (the pinned commit), what is reproduced (the functional behaviour of
the implementation on QEMU) and what is not (the hardware evaluation and the formal verification), and the differences observed between
the paper and the implementation. With it,
the G17 review and the sanitized G17 review log are added to the public evidence, as for every earlier gate. The two `test` lines confirm
that the README and this gate's files contain no local time-zone value and no listening port.

## 4. Audit everything that will be pushed

```bash
LOCAL_OFFSET="$(env -u TZ date +%:z)"
LOCAL_OFFSET_COMPACT="$(env -u TZ date +%z)"
LOCAL_ZONE="$(env -u TZ date +%Z)"
LOCAL_TZNAME="$(timedatectl show -p Timezone --value)"
test -n "$LOCAL_OFFSET" -a -n "$LOCAL_OFFSET_COMPACT" -a -n "$LOCAL_ZONE" -a -n "$LOCAL_TZNAME"
git merge-base --is-ancestor b11c247276c47c057014abca1c78e0c2882519d7 HEAD
test -z "$(git ls-files | grep -v -E '^(\.gitignore|LICENSE|NOTICE|README\.md|PROJECT_CHARTER\.md|docs/|scripts/|patches/|logs/public/)')"
test -z "$(git grep -l -I -w -F -f "$PROJECT_ROOT/build/private/listening-ports-high.txt" $(git rev-list --all))"
test -z "$(git grep -l -I -E 'Listening TCP ports: [0-9]|already in use: [0-9]|listens on [0-9]+ \(G00\)|for example [0-9]+, G00' $(git rev-list --all))"
test -z "$(awk '/^\$ ss -ltnH$/ {f = 1; next} f && /^\$ / {next} f && /^[0-9]+$/ {print FILENAME; next} {f = 0}' logs/public/review-logs/*)"
test -z "$(git grep -l -I -w -F -e "$(id -un)" -e "$(hostname)" $(git rev-list --all))"
test -z "$(git grep -l -I -F -e "$HOME" $(git rev-list --all))"
test -z "$(git grep -l -I -E '/home/[A-Za-z0-9_]' $(git rev-list --all))"
test -z "$(git grep -l -I -F -e "$LOCAL_OFFSET" -e "$LOCAL_OFFSET_COMPACT" -e "$LOCAL_TZNAME" $(git rev-list --all))"
test -z "$(git grep -l -I -w -F -e "$LOCAL_ZONE" $(git rev-list --all))"
test -z "$(git grep -l -I -E 'Requested-By: [^<[]|(Start|End)-Date: [0-9]' $(git rev-list --all))"
test -z "$(git grep -l -I -E 'BEGIN [A-Z ]*PRIVATE KEY|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}' $(git rev-list --all))"
test "$(git log --format='%aI%n%cI' | grep -c -v '+00:00$')" -eq 0
test "$(git log --format='%ae%n%ce' | sort -u)" = "238169016+junlinh12@users.noreply.github.com"
(cd logs/public && sha256sum -c --quiet SHA256SUMS)
git ls-files | wc -l
```

The same strict checks as G17, over the whole history that will be pushed, and one more: the published commit of G17 is an ancestor of
the new `HEAD`, so the push only adds a commit. If any check fails, nothing is pushed.

## 5. Log in once and push as a fast-forward

```bash
echo "Type the token at git's Password prompt. It is not shown and not stored on disk." > /dev/tty || true
git -c credential.helper= -c 'credential.helper=cache --timeout=300' push origin main || echo "(the push did not complete)"
```

An ordinary push, never `--force`; GitHub accepts it only as a fast-forward. git asks for the password on the terminal: paste the
fine-grained token there. As in G17, every configured credential helper is switched off for this command and the token is kept in memory
for at most 5 minutes. A failed push is recorded by the checks of step 6; this step does not stop the gate, so that step 7 always runs.

## 6. Verify without logging in what GitHub holds

```bash
git ls-remote "$PUBLIC_URL"
test "$(git ls-remote "$PUBLIC_URL" refs/heads/main | cut -f1)" = "$(git rev-parse HEAD)"
test "$(git ls-remote --heads "$PUBLIC_URL" | wc -l)" -eq 1
test "$(git rev-parse origin/main)" = "$(git rev-parse HEAD)"
test "$(curl -s "https://raw.githubusercontent.com/$REPO/$(git rev-parse HEAD)/README.md" | sha256sum | cut -d' ' -f1)" = "$(sha256sum < README.md | cut -d' ' -f1)"
git status -sb | sed -n '1p'
```

Everything is checked anonymously, as any reader would see it: GitHub has one branch, its commit is the local `HEAD`, and the
`README.md` that GitHub serves for exactly that commit is byte-identical to the local one.

## 7. Forget the token and check the credential settings

```bash
git credential-cache exit || echo "(no credential cache was running)"
git config --show-origin --get-all credential.helper || echo "(no credential helper configured)"
```

`git credential-cache exit` forgets the token at once. The configured credential helpers are shown again, to confirm that this gate
changed none of them.

## 8. Record the published state

```bash
git rev-parse HEAD
git log --oneline | wc -l
git log -2 --format='%h  %aI  %s'
git status --short
```

The published commit, the number of commits, the last two commits (G17's published state and this gate's commit), and the state of
the working tree.

## 9. Run all steps with logging

```bash
bash scripts/G18_readme_paper.sh
```

On the first run, use the downloaded copy: `bash ~/download/G18_readme_paper.sh`.
The script stops after steps 1 to 4 if a check failed, before any login. From step 5 on it does not stop early, so that the token is always
forgotten in step 7. If the push did not complete (for example because of a mistyped token), push again later with the commands of steps
5 to 7; step 2 of this script would then stop, because the local `HEAD` is already the new commit.

After the gate, delete the token on GitHub.
