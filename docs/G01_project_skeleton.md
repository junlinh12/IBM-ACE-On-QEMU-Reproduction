# G01: Project Skeleton

This gate creates the project layout, installs the charter and the G00 files, writes the Git
ignore rules, and sets a local Git identity that uses the GitHub no-reply address.
Nothing is cloned, built, committed, or pushed.

Previous gate: **G00 PASS** (see `logs/review/G00_review.md`).

The same commands are run, with logging, by [`scripts/G01_project_skeleton.sh`](../scripts/G01_project_skeleton.sh).

Set the paths first. `DOWNLOAD_DIR` is the folder that holds the six downloaded files
(`G01_project_skeleton.sh`, `G01_project_skeleton.md`, `PROJECT_CHARTER.md`,
`G00_host_baseline.sh`, `G00_host_baseline.md`, `G00_review.md`):

```bash
PROJECT_ROOT=~/projects/IBM-ACE-On-QEMU-Reproduction
DOWNLOAD_DIR=~/download
```

## 1. Verify the downloaded files and the G00 evidence

```bash
cd "$DOWNLOAD_DIR"
sha256sum G01_project_skeleton.sh G01_project_skeleton.md
echo "d88c31af440a9a8d820a46e3df4855c130a004db19602c00e5ec2aeb38e48fb4  G00_host_baseline.sh" | sha256sum -c -
echo "c542d734b4eabd0a4f94a8284f7f8522138f32512f0c6668a85f471321f98666  G00_host_baseline.md" | sha256sum -c -
echo "574fa11c5dd1c9d340634ed86aa6ca6d3b72c9d1b5d37476653ce8e7e305577e  G00_review.md" | sha256sum -c -
echo "75fa04fadf3bcb70f0575d2c06abb073e3059824346f03599a575a0b5aebde1e  PROJECT_CHARTER.md" | sha256sum -c -
cd "$PROJECT_ROOT/logs"
sha256sum -c G00_*.sha256
```

Expected: every check prints `OK`. If any check fails, stop.
The first line only records the hashes of the G01 files themselves (a file cannot contain its own hash).
The last line re-checks the sealed G00 evidence (raw log and input script) against its SHA-256 seal.

## 2. Create the project layout

```bash
cd "$PROJECT_ROOT"
mkdir -p scripts docs patches upstream build logs/public
touch logs/public/.keep
```

| Folder | Content | Published |
|---|---|---|
| `scripts/` | gate scripts | Yes |
| `docs/` | gate documents (this file) | Yes |
| `patches/` | changes to IBM sources, with reasons | Yes |
| `upstream/` | IBM ACE-RISCV checkout (G02) | No |
| `build/` | build output (`ACE_DIR`) | No |
| `logs/` | all evidence of this project (One Project, One Log System) | Only `public/` |

## 3. Install the charter, scripts, documents, and the G00 review

```bash
cp "$DOWNLOAD_DIR/PROJECT_CHARTER.md" PROJECT_CHARTER.md
cp "$DOWNLOAD_DIR/G00_host_baseline.sh" scripts/
cp "$DOWNLOAD_DIR/G01_project_skeleton.sh" scripts/
cp "$DOWNLOAD_DIR/G00_host_baseline.md" docs/
cp "$DOWNLOAD_DIR/G01_project_skeleton.md" docs/
cp "$DOWNLOAD_DIR/G00_review.md" logs/review/
```

If any copy fails, stop.

## 4. Write the Git ignore rules

```bash
cat > .gitignore <<'EOF'
# IBM upstream sources and build artifacts: never published
/upstream/
/build/

# logs: private by default
/logs/**

# Only material approved in G16 is published
!/logs/public/
!/logs/public/**

# Editor and OS files
*.swp
*~
.DS_Store
EOF
cat .gitignore
```

The rules deny by default: everything in `logs/` is ignored except `public/`.
Note that `.gitignore` cannot remove a file that was already committed; G16 also checks the Git history.

## 5. Create the local Git repository and identity

```bash
git init -b main
GITHUB_USER=junlinh12
GITHUB_ID=$(curl -fsS "https://api.github.com/users/$GITHUB_USER" | python3 -c 'import json, sys; print(json.load(sys.stdin)["id"])')
git config user.name "$GITHUB_USER"
git config user.email "$GITHUB_ID+$GITHUB_USER@users.noreply.github.com"
git config --local --list
```

The public GitHub API returns the account's numeric ID, which forms the no-reply address
`<ID>+<user>@users.noreply.github.com`. If the API call fails, stop: an empty ID would give a wrong address.
The identity is stored in `.git/config` of this repository only; the global Git configuration is not changed.

## 6. Check what Git would publish

```bash
git check-ignore -v upstream/ build/ logs/review/G00_review.md logs/G00_*.raw.log
git add --dry-run --all
git status --short
```

Expected: `check-ignore` shows a rule for every listed path.
`git add --dry-run` lists only `.gitignore`, `PROJECT_CHARTER.md`, `logs/public/.keep`,
and the files in `docs/` and `scripts/`. No `.raw.log`, `.input.sh`, `.sha256`, or `review/` file may appear.
Nothing is staged; the first commit is made after G01 is reviewed.

## 7. Record the project layout

```bash
find . -path ./.git -prune -o -print | sort
```

## 8. Run all steps with logging

```bash
bash scripts/G01_project_skeleton.sh
```

On the first run, use the downloaded copy: `bash ~/download/G01_project_skeleton.sh`.
The script stops after step 1, 3, or 5 if a check failed, and still seals the log.
Evidence files are the same kinds as in G00 (`raw.log`, `input.sh`, `sha256`, and a masked `review/` copy), in `logs/`.

Note for the reference host: the first G00 run wrote its evidence to a folder named `Project Logs/`.
Before step 1, the script renames that folder to `logs/` once (it stops if both folders exist), and
step 1 re-checks the moved G00 evidence against its seal. A new reproduction never has `Project Logs/`,
so nothing is renamed.
