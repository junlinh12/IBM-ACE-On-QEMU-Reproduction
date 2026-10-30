# G02: Fetch Upstream at the Pinned Commit

This gate downloads IBM ACE-RISCV at a fixed commit, fetches its submodules, and records
where every piece of source code comes from (success criterion E1).
It also makes the first local commit of this project, containing the reviewed G00-G01 work.
Nothing is built, installed, or pushed.

Previous gate: **G01 PASS** (see `logs/review/G01_review.md`).

The same commands are run, with logging, by [`scripts/G02_fetch_upstream.sh`](../scripts/G02_fetch_upstream.sh).

| Item | Value |
|---|---|
| Upstream | https://github.com/IBM/ACE-RISCV |
| Pinned commit | `1ebdebf4cacc04fcb83191053b4e979cbcdcb2d6` |
| Why this commit | `main` HEAD observed in G00 on 2026-10-30 |
| Checkout location | `upstream/ACE-RISCV` (ignored by this project's Git) |

Set the paths first:

```bash
PROJECT_ROOT=~/projects/IBM-ACE-On-QEMU-Reproduction
DOWNLOAD_DIR=~/download
```

## 1. Verify the downloaded files and all sealed evidence

```bash
cd "$DOWNLOAD_DIR"
sha256sum G02_fetch_upstream.sh G02_fetch_upstream.md
echo "101ee05e9d1cd8490033a483381a55089a29974653ecbe1641858ef6b5ff79b1  G01_review.md" | sha256sum -c -
cd "$PROJECT_ROOT/logs"
sha256sum -c *.sha256
sha256sum *.input.sh
```

Expected: every line ends with `OK`. If any check fails, stop.
`sha256sum -c *.sha256` re-checks every sealed log of earlier gates; this is repeated at the start of each gate.
`sha256sum *.input.sh` records which script produced each log.

## 2. Commit the reviewed G00-G01 work (local only)

```bash
cd "$PROJECT_ROOT"
cp "$DOWNLOAD_DIR/G01_review.md" logs/review/
git add .gitignore PROJECT_CHARTER.md logs/public/.keep scripts/G00_host_baseline.sh scripts/G01_project_skeleton.sh docs/G00_host_baseline.md docs/G01_project_skeleton.md
git status --short
git diff --cached --quiet || git commit -m "G00-G01: host baseline and project skeleton"
git log -1 --format='commit %H%nauthor %an <%ae>%ndate   %aI%n%n    %s'
git show --stat --format= HEAD
cp "$DOWNLOAD_DIR/G02_fetch_upstream.sh" scripts/
cp "$DOWNLOAD_DIR/G02_fetch_upstream.md" docs/
```

Files are added by name, not with `git add --all`, so only the reviewed files enter the commit.
Expected: the author is `junlinh12 <238169016+junlinh12@users.noreply.github.com>`, and the commit
contains exactly the 7 files listed. The commit is local; nothing is pushed until G17.
The G02 files are copied after the commit; they are committed after G02 is reviewed.

## 3. Clone the upstream repository

```bash
cd "$PROJECT_ROOT/upstream"
date -u
[ -d ACE-RISCV/.git ] || GIT_TERMINAL_PROMPT=0 git clone https://github.com/IBM/ACE-RISCV.git ACE-RISCV
date -u
```

HTTPS is used instead of the `git@github.com:` address in the upstream README, so no SSH key is needed.
`GIT_TERMINAL_PROMPT=0` makes Git fail instead of asking for a password.
If the clone already exists (re-run), it is reused.

## 4. Check out the pinned commit

```bash
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
git checkout --detach 1ebdebf4cacc04fcb83191053b4e979cbcdcb2d6
git rev-parse HEAD
git log -1 --format='commit  %H%ndate    %cI%nsubject %s'
git rev-parse origin/main
git status --short
```

Expected: `git rev-parse HEAD` prints the pinned commit, and `git status --short` prints nothing.
`git rev-parse origin/main` shows whether upstream `main` has moved since G00; the pin does not change if it has.

## 5. Record the submodule pins before fetching

```bash
cat .gitmodules
git submodule status
```

Each line of `git submodule status` starts with `-` (not yet fetched), then the commit that the
pinned ACE commit requires for that submodule.

## 6. Fetch the submodules

```bash
date -u
GIT_TERMINAL_PROMPT=0 git -c url."https://github.com/".insteadOf="git@github.com:" submodule update --init --recursive
date -u
git submodule status --recursive
```

This follows the upstream README (`git submodule update --init --recursive`).
The `-c url...insteadOf` option applies to this command only: any submodule address of the form
`git@github.com:` is fetched over HTTPS instead, so no SSH key is needed. Nothing is written to the Git configuration.
Expected: every line of `git submodule status --recursive` starts with a space (checked out at the required commit),
not `-` (missing) or `+` (different commit). This step can take a long time.

## 7. Record the build inputs declared by upstream

```bash
cat rust-toolchain.toml
cat .github/workflows/build.yml
git grep -nE 'https?://|git://' -- '*Makefile*' '*.mk'
```

These record, from the pinned commit itself:
the Rust nightly version (used in G04), the packages and build order of the upstream CI
(used in G03 to decide whether `llvm-dev` is required), and every external URL the Makefiles
download from at build time (tool binaries, source archives, extra repositories).

## 8. Check the result

```bash
git status --short
du -sh "$PROJECT_ROOT/upstream/ACE-RISCV"
df -h "$PROJECT_ROOT"
cd "$PROJECT_ROOT"
git check-ignore -v upstream/ACE-RISCV
git status --short
```

Expected: the upstream checkout is clean; `upstream/ACE-RISCV` is ignored by this project's Git;
the project's `git status` shows only the two new G02 files.

## 9. Run all steps with logging

```bash
bash scripts/G02_fetch_upstream.sh
```

On the first run, use the downloaded copy: `bash ~/download/G02_fetch_upstream.sh`.
The script stops after step 1, 2, 3, 4, or 6 if a check failed, and still seals the log.
It can be run again after a network failure: the existing clone is reused and the commit is not repeated.
