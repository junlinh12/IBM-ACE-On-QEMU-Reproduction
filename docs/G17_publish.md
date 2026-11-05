# G17: Publish to the Private GitHub Repository

This gate pushes the audited repository to `github.com/junlinh12/IBM-ACE-On-QEMU-Reproduction`, which the owner created as a **private**,
empty repository, and verifies what GitHub received. It does not make the repository public: the owner reviews it on GitHub and changes its
visibility there (owner's decision, checkpoint 4).

Previous gate: **G16c PASS** (see `logs/review/G16c_review.md`).

The same commands are run, with logging, by [`scripts/G17_publish.sh`](../scripts/G17_publish.sh).

## Before running

| Preparation | How |
|---|---|
| Private, empty repository | GitHub: New repository, name `IBM-ACE-On-QEMU-Reproduction`, **Private**, without README, `.gitignore`, or license |
| Token for this repository only | GitHub: Settings, Developer settings, Personal access tokens, **Fine-grained tokens**, Generate new token: a short expiration (for example 7 days); Repository access **Only select repositories**: `IBM-ACE-On-QEMU-Reproduction`; Repository permissions **Contents: Read and write** |
| A terminal | run the script in a terminal (or `tmux`), because git asks for the token there |

**The token is a password.** Never paste it into a chat, a file, or a command line. It is typed only at git's `Password` prompt; git keeps it in
memory for at most 5 minutes, and step 9 erases it. After the owner has made the repository public, the token can be deleted on GitHub.

Set the paths first:

```bash
PROJECT_ROOT=~/projects/IBM-ACE-On-QEMU-Reproduction
DOWNLOAD_DIR=~/download
```

## 1. Verify the downloaded files and all sealed evidence

```bash
cd "$DOWNLOAD_DIR"
sha256sum G17_publish.sh G17_publish.md
echo "ed8218c7ab75a03011a852beb77f84a1ed12ff3b4193e8d6988f9eef7cffbd84  G16c_review.md" | sha256sum -c -
echo "dd73e63c886782a4a370dd83808a5593187fd3a9abe78a43459d58d6d38e2591  G16c_port_masking.md" | sha256sum -c -
cd "$PROJECT_ROOT/logs"
sha256sum -c *.sha256
```

Expected: every line ends with `OK`. If any check fails, stop.

## 2. Commit the reviewed G16c work and this gate's files, with sanitized evidence

```bash
cd "$PROJECT_ROOT"
cp "$DOWNLOAD_DIR/G16c_review.md" logs/review/
cp "$DOWNLOAD_DIR/G17_publish.sh" scripts/
cp "$DOWNLOAD_DIR/G17_publish.md" docs/
cp "$DOWNLOAD_DIR/G16c_port_masking.md" docs/G16c_port_masking.md
PORTS="$PROJECT_ROOT/build/private/listening-ports.txt"
test -s "$PORTS"
test -z "$(grep -F -e "$(env -u TZ date +%:z)" -e "$(env -u TZ date +%z)" -e "$(timedatectl show -p Timezone --value)" scripts/G16c_port_masking.sh docs/G16c_port_masking.md scripts/G17_publish.sh docs/G17_publish.md)"
test -z "$(grep -w -F -e "$(env -u TZ date +%Z)" -f "$PROJECT_ROOT/build/private/listening-ports-high.txt" scripts/G16c_port_masking.sh docs/G16c_port_masking.md scripts/G17_publish.sh docs/G17_publish.md)"
rm -rf logs/public/reviews logs/public/review-logs
mkdir -p logs/public/reviews logs/public/review-logs
for f in logs/review/*.md; do scripts/sanitize_evidence.sh --ports "$PORTS" < "$f" > "logs/public/reviews/$(basename "$f")"; done
for f in logs/review/G0[0-7]*.review.log; do scripts/sanitize_evidence.sh --pre-utc --ports "$PORTS" < "$f" > "logs/public/review-logs/$(basename "$f")"; done
for f in logs/review/G0[89]*.review.log logs/review/G1*.review.log; do scripts/sanitize_evidence.sh --ports "$PORTS" < "$f" > "logs/public/review-logs/$(basename "$f")"; done
(cd logs/review && sha256sum *.md *.review.log) > logs/public/ORIGINALS.sha256
(cd logs/public && find reviews review-logs -type f | sort | xargs sha256sum) > logs/public/SHA256SUMS
ls logs/public/reviews | wc -l
ls logs/public/review-logs | wc -l
git add scripts/G16c_port_masking.sh docs/G16c_port_masking.md scripts/G17_publish.sh docs/G17_publish.md logs/public
git status --short
TZ=UTC0 git commit -q -m "G16c: gate files and sanitized evidence; G17 gate files"
git log -1 --format='%h  %aI  %an <%ae>  %s'
```

The G16c document is first replaced by its published copy, whose prose avoids a phrase that the strict apt check would match (G16c
review F5); its commands are unchanged. The G16c script and document and this gate's script and document are then committed with the sanitized copies of everything reviewed so far,
including the G16c review log and `G16c_review.md`. The two `test` lines first confirm that none of the four new gate files contains a local
time-zone value or a listening port (both read at run time, as in G16c). This gate's own review log is written after the push and is
therefore not part of this publication.

## 3. Audit everything that will be pushed, a last time

```bash
LOCAL_OFFSET="$(env -u TZ date +%:z)"
LOCAL_OFFSET_COMPACT="$(env -u TZ date +%z)"
LOCAL_ZONE="$(env -u TZ date +%Z)"
LOCAL_TZNAME="$(timedatectl show -p Timezone --value)"
test -n "$LOCAL_OFFSET" -a -n "$LOCAL_OFFSET_COMPACT" -a -n "$LOCAL_ZONE" -a -n "$LOCAL_TZNAME"
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
git ls-files -z | xargs -0 du -b | sort -n | tail -n 3
```

The same checks as G16c, now over the history that will be pushed, as strict `test` lines, and three more: only the allowed paths are
tracked (`.gitignore`, `LICENSE`, `NOTICE`, `README.md`, `PROJECT_CHARTER.md`, `docs/`, `scripts/`, `patches/`, `logs/public/`); every
author and committer address is the no-reply address; and the three largest tracked files are listed, to see that no build output slipped in.
If any check fails, nothing is pushed.

## 4. Check without logging in that the repository is not public

```bash
REPO=junlinh12/IBM-ACE-On-QEMU-Reproduction
curl -s -o /dev/null -w '%{http_code}\n' "https://api.github.com/repos/$REPO"
test "$(curl -s -o /dev/null -w '%{http_code}' "https://api.github.com/repos/$REPO")" = 404
```

The GitHub API is asked anonymously, so no credential is sent. A private repository answers `404`, exactly like a missing one; a public
repository answers `200`. The gate stops on anything but `404`, because the owner decided to publish privately first.

## 5. Set the remote in the local configuration and check the credential settings

```bash
URL="https://junlinh12@github.com/$REPO.git"
git remote get-url origin 2>/dev/null || git remote add origin "$URL"
test "$(git config --get remote.origin.url)" = "$URL"
git config --show-origin --get-all credential.helper || echo "(no credential helper configured)"
env | grep -E '^(GIT_ASKPASS|SSH_ASKPASS|GIT_TERMINAL_PROMPT)=' || echo "(no prompt override in the environment)"
```

The remote is set in the project's own configuration (`.git/config`); no global setting changes. The URL contains the user name, so
git asks only for the password, which is the token. The last two lines show whether a credential helper is configured on this host (it is
switched off for this gate's commands in steps 6-8) and whether the environment overrides git's prompt.

## 6. Log in once and check that the repository on GitHub is empty

```bash
echo "Type the token at git's Password prompt. It is not shown and not stored on disk." > /dev/tty || true
REMOTE_REFS="$(git -c credential.helper= -c 'credential.helper=cache --timeout=300' ls-remote origin)" && LS_OK=1 || LS_OK=0
echo "login and read: $LS_OK; references on GitHub before the push: $(printf '%s' "$REMOTE_REFS" | grep -c .)"
test "$LS_OK" = 1
```

`echo ... > /dev/tty` writes the hint to the terminal, because the gate's output goes to its log. git then asks for the password on the
terminal: paste the fine-grained token there. `-c credential.helper=` switches off every configured helper for this command, so the token
cannot be stored on disk, and `cache --timeout=300` keeps it in memory for 5 minutes, so that steps 7 and 8 do not ask again. A failed login
or read is recorded and prevents the push; nothing in this step stops the gate, so that step 9 always forgets the token.

## 7. Push only if the repository on GitHub is empty

```bash
if [ "$LS_OK" = 1 ] && [ -z "$REMOTE_REFS" ]; then git -c credential.helper= -c 'credential.helper=cache --timeout=300' push -u origin main; else echo "(nothing was pushed: the repository could not be read or is not empty)"; fi
```

The push happens only if the login worked and GitHub has no reference yet. It is an ordinary push, never `--force`: a repository that is
not empty is left untouched.

## 8. Verify what GitHub received

```bash
git -c credential.helper= -c 'credential.helper=cache --timeout=300' ls-remote origin
test "$(git -c credential.helper= -c 'credential.helper=cache --timeout=300' ls-remote --heads origin | wc -l)" -eq 1
test "$(git -c credential.helper= -c 'credential.helper=cache --timeout=300' ls-remote origin refs/heads/main | cut -f1)" = "$(git rev-parse HEAD)"
test "$(git rev-parse origin/main)" = "$(git rev-parse HEAD)"
git status -sb | sed -n '1p'
```

GitHub must now have exactly one branch, and its commit must be the local `HEAD`; Git commit hashes cover the whole content and history,
so equal hashes mean that GitHub received exactly what was audited. `origin/main` is the local record of the push.

## 9. Forget the token and check that the repository is still private

```bash
git credential-cache exit || echo "(no credential cache was running)"
test "$(curl -s -o /dev/null -w '%{http_code}' "https://api.github.com/repos/$REPO")" = 404
git config --show-origin --get-all credential.helper || echo "(no credential helper configured)"
git remote -v
```

`git credential-cache exit` ends the in-memory cache, so the token is forgotten at once instead of after 5 minutes. The anonymous check of
step 4 is repeated: the repository must still be private. The configured credential helpers are shown again, to confirm that this gate
changed none of them.

## 10. Record the published state

```bash
git rev-parse HEAD
git log --oneline | wc -l
git log -1 --format='%h  %aI  %s'
git status --short
```

The pushed commit, the number of commits, and the state of the working tree.

## 11. Run all steps with logging

```bash
bash scripts/G17_publish.sh
```

On the first run, use the downloaded copy: `bash ~/download/G17_publish.sh`.
The script stops after steps 1 to 5 if a check failed, before any login. From step 6 on it does not stop early, so that the token is always
forgotten in step 9. If the push did not happen (for example because of a mistyped token), the script can be run again: step 2 then only
commits again if something changed, and the push is repeated only if the repository on GitHub is still empty.

## After this gate

1. Review the repository on GitHub (it is private, so only the owner sees it).
2. To publish it: repository Settings, General, Danger Zone, **Change visibility**, Public.
3. Delete the token: Settings, Developer settings, Personal access tokens, Fine-grained tokens.
