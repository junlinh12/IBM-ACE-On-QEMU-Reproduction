# G07: Build the ACE Tools (`make tools`)

`make tools` installs the ACE command-line scripts (`ace`, `ace_run_hypervisor.sh`, `common.sh`, and the
others in `tools/`) into `$ACE_DIR/tools`, and builds the TAP tool `cove-tap-tool`. The TAP tool measures the
confidential VM's kernel and writes the TVM attestation payload (TAP) with the expected measurement and the
demo secret (`docs/SAFETY_AUDIT.md`, A15), so it is needed before the confidential VM can be built (G11).

Previous gate: **G06 PASS**. The first run of G07 was **BLOCKED** at the check in step 6 below
(`logs/review/G07_run1_review.md`): the host's `stable` Rust toolchain has no `rustfmt`, which the TAP tool's
Makefile needs for `cargo fmt`. This revision builds the TAP tool with a separately installed Rust `1.98.1`
(the same release as the host's `stable`), so the shared `stable` toolchain is not modified.

The same commands are run, with logging, by [`scripts/G07_tools.sh`](../scripts/G07_tools.sh).

| Item | Value | Source |
|---|---|---|
| Rust toolchain declared for the TAP tool | `stable` | `tools/cove_tap_tool/rust-toolchain.toml` (SAFETY_AUDIT A13) |
| Rust toolchain used | `1.98.1` with `rustfmt`, selected by `RUSTUP_TOOLCHAIN` for `make tools` only | this gate; checked equal to the host's `stable` |
| Crates | versions and checksums pinned | `tools/cove_tap_tool/Cargo.lock` |
| Crate download location | `build/cargo-home` | `CARGO_HOME` in `scripts/build_env.sh` |
| Build output | `$ACE_DIR/cove_tap_tool`, installed to `$ACE_DIR/tools` | `tools/cove_tap_tool/Makefile:13,27-28` |

Set the paths first:

```bash
PROJECT_ROOT=~/projects/IBM-ACE-On-QEMU-Reproduction
DOWNLOAD_DIR=~/download
```

## 1. Verify the downloaded files and all sealed evidence

```bash
cd "$DOWNLOAD_DIR"
sha256sum G07_tools.sh G07_tools.md
echo "dfbfc14deddc132b5b93cb1abab9da05f92b9dcf289cdb0a193016db7fff87cc  G06_review.md" | sha256sum -c -
echo "9525f71a312ad4d2e94bc80a5ce55089b9389d57e4f497a842b5bfddcf895b57  G07_run1_review.md" | sha256sum -c -
cd "$PROJECT_ROOT/logs"
sha256sum -c *.sha256
```

Expected: every line ends with `OK`. If any check fails, stop.

## 2. Commit the reviewed G06 work (local only, UTC)

```bash
cd "$PROJECT_ROOT"
cp "$DOWNLOAD_DIR/G06_review.md" logs/review/
cp "$DOWNLOAD_DIR/G07_run1_review.md" logs/review/
git add scripts/G06_devtools.sh docs/G06_devtools.md
git status --short
git diff --cached --quiet || TZ=UTC0 git commit -m "G06: RISC-V GNU toolchain (make devtools)"
git log -1 --format='%h  %aI  %an <%ae>  %s'
cp "$DOWNLOAD_DIR/G07_tools.sh" scripts/
cp "$DOWNLOAD_DIR/G07_tools.md" docs/
```

The G06 work was already committed by the first G07 run, so no new commit is made here.

## 3. Record the host and source state before the build

```bash
uname -r
free -h
df -h "$PROJECT_ROOT"
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
git status --short
```

Expected: the upstream checkout shows exactly the 5 files changed by patches 0001 and 0002.

## 4. Set the build environment

```bash
source "$PROJECT_ROOT/scripts/build_env.sh"
env | grep -E '^(ACE_DIR|QEMU_SOURCE_DIR|BR2_DL_DIR|CARGO_HOME|BR2_JLEVEL|OMP_NUM_THREADS|CARGO_BUILD_JOBS)=' | sort
```

## 5. Install Rust 1.98.1 for the TAP tool (stable and default unchanged)

```bash
rustup toolchain list
rustup toolchain install 1.98.1 --profile minimal --component rustfmt --no-self-update
rustup toolchain list
rustup default
```

`rustup toolchain install` only adds a toolchain; it never changes `stable` or the default (as in G04).
The minimal profile contains `rustc`, `cargo`, and the standard library; `rustfmt` is added for `cargo fmt`.

## 6. Select Rust 1.98.1 for the TAP tool and check it equals the host's stable

```bash
cd "$PROJECT_ROOT/upstream/ACE-RISCV/tools/cove_tap_tool"
cat rust-toolchain.toml; echo
rustup run stable rustc --version
export RUSTUP_TOOLCHAIN=1.98.1
rustup show active-toolchain
rustc --version
cargo --version
cargo fmt --version
test "$(rustup run stable rustc --version)" = "$(rustc --version)"
```

`RUSTUP_TOOLCHAIN` takes precedence over `rust-toolchain.toml` and applies only to this shell.
The last line fails unless the selected compiler prints exactly the same version line as the host's `stable`,
so the TAP tool is built with the Rust release that the upstream file would select today. If it fails (for
example after `stable` was updated), stop and review the choice. `cargo fmt --version` must succeed; this is the
check that blocked the first run.

## 7. Build the tools with the upstream Makefile

```bash
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
date -u
make -j2 tools
date -u
unset RUSTUP_TOOLCHAIN
```

This is the upstream procedure, unchanged (`Makefile:90-94`): copy the scripts in `tools/` to `$ACE_DIR/tools`,
then build the TAP tool with `cargo build --release` (2 jobs, `CARGO_BUILD_JOBS`). `make tools` builds nothing
else, so `RUSTUP_TOOLCHAIN` affects only the TAP tool; it is removed right after the build.

## 8. Verify the installed tools

```bash
ls -l "$ACE_DIR/tools"
sha256sum "$ACE_DIR/tools/cove-tap-tool"
"$ACE_DIR/tools/cove-tap-tool" --help
grep -c 'hostfwd=tcp:127.0.0.1:' "$ACE_DIR/tools/ace_run_hypervisor.sh"
grep -c 'UserKnownHostsFile=/dev/null' "$ACE_DIR/tools/common.sh"
```

The SHA-256 of the TAP tool is recorded for E2. The two `grep -c` lines must print `1`: they show that the copies
installed in `$ACE_DIR/tools`, which the run gates will use, contain the changes of patch 0002.

## 9. Record the crates that were downloaded

```bash
find "$CARGO_HOME/registry/cache" -name '*.crate' | wc -l
find "$CARGO_HOME/registry/cache" -name '*.crate' -printf '%f\n' | sort
du -sh "$CARGO_HOME"
```

Cargo verifies every crate against the checksum in `Cargo.lock`, so the list of crate files and the pinned
`Cargo.lock` together record the exact third-party sources (E1).

## 10. Check the upstream tree, the shared Rust setup, and the project

```bash
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
git status --short
git diff --stat
rustup default
rustup component list --installed --toolchain stable
cd "$PROJECT_ROOT"
git status --short
free -h
```

Expected: the upstream checkout shows the 5 patched files; any further file was changed by the build itself
(for example by `cargo fmt`, SAFETY_AUDIT A11) and is listed for the review. The default toolchain is still
`stable`, and `stable` still has no `rustfmt` component: the shared setup is unchanged. The project shows only
the G07 files.

## 11. Run all steps with logging

```bash
bash scripts/G07_tools.sh
```

On the first run of this revision, use the downloaded copy: `bash ~/download/G07_tools.sh`.
The script stops after step 1, 2, 4, 5, 6, or 7 if a check failed, and still seals the log.
