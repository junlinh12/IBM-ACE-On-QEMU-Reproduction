# G04: Install the Pinned Rust Toolchain

This gate installs the Rust toolchain declared by the pinned upstream commit, without changing the
default toolchain that other projects on the host use. It also records which Rust tools the upstream
Makefiles call, and commits the reviewed G03 work locally.

Previous gate: **G03 PASS** (see `logs/review/G03_review.md`).

The same commands are run, with logging, by [`scripts/G04_rust_toolchain.sh`](../scripts/G04_rust_toolchain.sh).

| Item | Value | Source |
|---|---|---|
| Toolchain | `nightly-2026-03-23` | `upstream/ACE-RISCV/rust-toolchain.toml` |
| Target | `riscv64gc-unknown-none-elf` | `rust-toolchain.toml` |
| Profile and extra component | `default` profile, `rustfmt` | the upstream CI installs with the default profile and adds `rustfmt` |

The upstream README and CI run `rustup default nightly`. This project does not, because that would change
the toolchain of every other project on the host. Inside `upstream/ACE-RISCV`, the `rust-toolchain.toml`
file selects `nightly-2026-03-23` automatically, so the build uses the same compiler either way.

Set the paths first:

```bash
PROJECT_ROOT=~/projects/IBM-ACE-On-QEMU-Reproduction
DOWNLOAD_DIR=~/download
```

## 1. Verify the downloaded files and all sealed evidence

```bash
cd "$DOWNLOAD_DIR"
sha256sum G04_rust_toolchain.sh G04_rust_toolchain.md
echo "fafb35fa2c704138d2c2354eb6b6cdfcc01f5fd3647261d209852ad4aa7b31eb  G03_review.md" | sha256sum -c -
cd "$PROJECT_ROOT/logs"
sha256sum -c *.sha256
```

Expected: every line ends with `OK`. If any check fails, stop.

## 2. Commit the reviewed G03 work (local only, UTC)

```bash
cd "$PROJECT_ROOT"
cp "$DOWNLOAD_DIR/G03_review.md" logs/review/
git add scripts/G03_apt_packages.sh docs/G03_apt_packages.md
git status --short
git diff --cached --quiet || TZ=UTC0 git commit -m "G03: install llvm-dev required by the upstream CI"
git log -1 --format='%h  %aI  %an <%ae>  %s'
git show --stat --format= HEAD
cp "$DOWNLOAD_DIR/G04_rust_toolchain.sh" scripts/
cp "$DOWNLOAD_DIR/G04_rust_toolchain.md" docs/
```

Expected: a commit with the 2 G03 files and a `+00:00` date.

## 3. Record the Rust state before the change

```bash
rustup --version
rustup toolchain list
rustup default
cat "$PROJECT_ROOT/upstream/ACE-RISCV/rust-toolchain.toml"
```

This records the default toolchain before the change, so step 6 can show that it is unchanged.

## 4. Record which Rust tools the upstream build uses

```bash
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
git ls-files '*rust-toolchain*' '*Cargo.toml' '*.cargo/config*'
git grep -nE 'cargo|rustup|rustc|rustfmt|clippy|objcopy' -- '*Makefile*' '*.mk' || echo "(no matches)"
```

The first command lists every Rust project and toolchain file in the pinned commit (a subproject could
declare its own toolchain). The second lists every call to a Rust tool in the Makefiles, for example
`cargo fmt`, `cargo clippy`, or `cargo objcopy` (which would need `cargo-binutils`, listed in the README
but not installed by the CI). If nothing matches, `(no matches)` is printed instead of failing,
because this step only records information.

## 5. Install the pinned nightly (the default is not changed)

```bash
date -u
rustup toolchain install nightly-2026-03-23 --profile default --target riscv64gc-unknown-none-elf --component rustfmt --no-self-update
date -u
```

`rustup toolchain install` only adds a toolchain; it never changes the default.
`--no-self-update` keeps the `rustup` program itself unchanged. Dated nightlies stay available on
`static.rust-lang.org`, so this step can be repeated later with the same result.

## 6. Verify the toolchain inside and outside the upstream tree

```bash
rustup toolchain list
rustup default
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
rustup show active-toolchain
rustc --version
cargo --version
rustup target list --installed
rustup component list --installed
cd "$PROJECT_ROOT"
rustup show active-toolchain
rustc --version
```

Expected:

- `rustup default` still shows the stable toolchain from step 3.
- Inside `upstream/ACE-RISCV`, the active toolchain is `nightly-2026-03-23`, overridden by `rust-toolchain.toml`,
  and the installed targets include `riscv64gc-unknown-none-elf`.
- Outside it, in the project root, the active toolchain is the unchanged default.

## 7. Check the project repository

```bash
cd "$PROJECT_ROOT"
git status --short
git log --format='%h  %aI  %s'
```

Expected: only the two new G04 files are untracked, and there are three commits.

## 8. Run all steps with logging

```bash
bash scripts/G04_rust_toolchain.sh
```

On the first run, use the downloaded copy: `bash ~/download/G04_rust_toolchain.sh`.
The script stops after step 1, 2, or 5 if a check failed, and still seals the log.
