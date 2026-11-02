# G05: Audit the Upstream Build and Run Scripts (read-only)

Before anything is built or run, this gate records the full text of every upstream Makefile and run
script, with line numbers, so that their side effects can be reviewed and cited by path and line.
It is read-only: nothing is built, run, patched, or installed.

What the review looks for:

| Concern | Why it matters on this host |
|---|---|
| Deletions (`rm -rf`) and their targets | must stay inside the build directory |
| Process kills (`kill`, `pkill`) | other experiments on the host also run QEMU |
| Network exposure (`hostfwd`) and fixed passwords | an SSH port forward without `127.0.0.1` is reachable from the network |
| Source modification during the build (`cargo fmt`, patching OpenSBI) | the pinned upstream tree must stay unmodified, or every change must be recorded |
| Parallelism (`-j`, `nproc`, Buildroot `BR2_JLEVEL`) | builds must respect `-j2` (charter 4.7) |
| External downloads | each must be recorded for reproducibility (E1) |
| Test success criteria | a test script that exits 0 without running tests would hide failures |

Previous gate: **G04 PASS** (see `logs/review/G04_review.md`). Checkpoint 1 was recorded after G04
(`logs/review/CHECKPOINT_1.md`).

The same commands are run, with logging, by [`scripts/G05_audit_build_scripts.sh`](../scripts/G05_audit_build_scripts.sh).

Set the paths first:

```bash
PROJECT_ROOT=~/projects/IBM-ACE-On-QEMU-Reproduction
DOWNLOAD_DIR=~/download
```

## 1. Verify the downloaded files and all sealed evidence

```bash
cd "$DOWNLOAD_DIR"
sha256sum G05_audit_build_scripts.sh G05_audit_build_scripts.md
echo "16da5430a362ffa750fba019786c44d8bd5a286d99eb5169c891f254fea264f0  G04_review.md" | sha256sum -c -
echo "6d0e9db7e6f48ab2956a70086ddef5fb552c9c5cd69d0b7f303c6a85bdc7d42d  CHECKPOINT_1.md" | sha256sum -c -
echo "8bcf3e3afb1c34524803e47ef9015c64e52139cb9e6ec70efa69185cf13da045  PROJECT_CHARTER.md" | sha256sum -c -
cd "$PROJECT_ROOT/logs"
sha256sum -c *.sha256
```

Expected: every line ends with `OK`. If any check fails, stop.

## 2. Commit the reviewed G04 work and charter v1.3 (local only, UTC)

```bash
cd "$PROJECT_ROOT"
cp "$DOWNLOAD_DIR/G04_review.md" logs/review/
cp "$DOWNLOAD_DIR/CHECKPOINT_1.md" logs/review/
cp "$DOWNLOAD_DIR/PROJECT_CHARTER.md" PROJECT_CHARTER.md
git add PROJECT_CHARTER.md scripts/G04_rust_toolchain.sh docs/G04_rust_toolchain.md
git status --short
git diff --cached --quiet || TZ=UTC0 git commit -m "G04: install Rust nightly-2026-03-23; checkpoint 1"
git log -1 --format='%h  %aI  %an <%ae>  %s'
git show --stat --format= HEAD
cp "$DOWNLOAD_DIR/G05_audit_build_scripts.sh" scripts/
cp "$DOWNLOAD_DIR/G05_audit_build_scripts.md" docs/
```

Charter v1.3 moves the checkpoints to after every 5 completed gates (after G04, G09, G14, and before G17).

## 3. Record the host state for this gate

```bash
uname -r
free -h
```

## 4. Record the upstream file layout

```bash
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
git ls-files -- ':(exclude)security-monitor/src' ':(exclude)verification'
```

Paths only. The security monitor's Rust sources and the formal verification are excluded to keep the list short.

## 5. Record every Makefile with line numbers

```bash
git ls-files -z -- '*Makefile*' '*.mk' ':(exclude)verification' | xargs -0 -r grep -IHn ''
```

`grep -IHn ''` prints every line as `path:line:text` and skips binary files.
`xargs -r` runs nothing when the file list is empty, instead of making `grep` wait for input.
The submodules (Buildroot, OpenSBI) are not included; only the ACE files are.

## 6. Record the run scripts and tools with line numbers

```bash
git ls-files -z -- tools ':(exclude)tools/cove_tap_tool/src' | xargs -0 -r grep -IHn ''
```

This includes the run and test scripts and `tools/cove_tap_tool/rust-toolchain.toml` (G04 F1).

## 7. Index the operations that need review

```bash
git grep -nE 'rm -rf|kill|sudo|hostfwd|git apply|patch |\$\(CARGO\)|cargo fmt|nproc|JLEVEL|-j ?[0-9]' -- ':(exclude)verification' ':(exclude)*.rs' ':(exclude)*.md' || echo "(no matches)"
git grep -nE 'https?://|git://' -- ':(exclude)verification' ':(exclude)*.rs' ':(exclude)*.md' ':(exclude)*Makefile*' || echo "(no matches)"
```

The first command is an index of the concerns in the table above. The second finds external URLs outside
the Makefiles (for example in Buildroot configuration files), which G02 did not scan.

## 8. Check that the build-time Git sources are reachable

```bash
GIT_TERMINAL_PROMPT=0 timeout 30 git ls-remote git://git.kernel.org/pub/scm/utils/dtc/dtc.git HEAD || echo "(git:// unreachable)"
GIT_TERMINAL_PROMPT=0 timeout 30 git ls-remote https://git.kernel.org/pub/scm/utils/dtc/dtc.git HEAD || echo "(https unreachable)"
GIT_TERMINAL_PROMPT=0 timeout 30 git ls-remote https://github.com/wojciechozga/kvmtool.git refs/heads/cove-integration-03072023 || echo "(unreachable)"
```

`hypervisor/Makefile` clones dtc over `git://` (port 9418), which some networks block; the HTTPS address
is checked as a fallback. The kvmtool line records the commit the branch points to today.
These lines only report; an unreachable source is a finding for the review, not a failure of this gate.

## 9. Check that nothing was modified

```bash
git status --short
cd "$PROJECT_ROOT"
git status --short
```

Expected: the upstream tree is clean; the project shows only the two new G05 files.

## 10. Run all steps with logging

```bash
bash scripts/G05_audit_build_scripts.sh
```

On the first run, use the downloaded copy: `bash ~/download/G05_audit_build_scripts.sh`.
The script stops after step 1 or 2 if a check failed, and still seals the log.

After the review of this gate, the required safety changes are written as patch files in `patches/`
(the IBM sources are never edited by hand) and applied, with logging, by a second G05 run.
