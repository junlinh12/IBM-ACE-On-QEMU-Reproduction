# G10: Build the Firmware: OpenSBI with the ACE Security Monitor (`make firmware`)

`make firmware` builds the trusted part of ACE: the security monitor, written in Rust and compiled into the static library
`libace.a`, linked into OpenSBI, the RISC-V machine-mode firmware. The hypervisor kernel from G09 is embedded as OpenSBI's
payload. The result, `fw_payload.elf`, is what `tools/ace_run_hypervisor.sh` boots on the emulated platform (G13).

Previous gate: **G09 PASS** (see `logs/review/G09_review.md`). Checkpoint 2 was recorded after G09
(`logs/review/CHECKPOINT_2.md`).

The same commands are run, with logging, by [`scripts/G10_firmware.sh`](../scripts/G10_firmware.sh).

| Item | Value | Source |
|---|---|---|
| Make target | `firmware` -> `security-monitor` target `opensbi` -> `build` -> `opensbi_bindings`, `fmt` | `Makefile:73-74`, `security-monitor/Makefile:28-69` |
| Security monitor | `cargo build --release --target=riscv64gc-unknown-none-elf --features verbose`, Rust `nightly-2026-03-23` | `security-monitor/Makefile:34`, `rust-toolchain.toml` |
| OpenSBI | submodule `security-monitor/opensbi` (v1.4-13), patched with `security-monitor/platform/opensbi_v1.4.patch` | `security-monitor/Makefile:54-57` |
| Payload | `$ACE_DIR/hypervisor/buildroot/images/Image` (G09, SHA-256 `75a0db25...08d7`) | `Makefile:24` (`LINUX_IMAGE`) |
| Output | `$ACE_DIR/security-monitor/opensbi/platform/generic/firmware/fw_payload.elf` | `tools/ace_run_hypervisor.sh:12` |
| Jobs | OpenSBI `-j$(shell nproc)` with `OMP_NUM_THREADS=2` (patch 0001); cargo `CARGO_BUILD_JOBS=2` | SAFETY_AUDIT A2-A4 |

Two changes to the upstream tree are made by the upstream build itself and are recorded, not prevented
(SAFETY_AUDIT A11): `cargo fmt` may reformat the security monitor's sources, and the OpenSBI submodule is patched.

Set the paths first:

```bash
PROJECT_ROOT=~/projects/IBM-ACE-On-QEMU-Reproduction
DOWNLOAD_DIR=~/download
```

## 1. Verify the downloaded files and all sealed evidence

```bash
cd "$DOWNLOAD_DIR"
sha256sum G10_firmware.sh G10_firmware.md
echo "8179cb84db36612bf18abb04bfc8c15a8f22f39c64795f2da1511eaca0cf6460  G09_review.md" | sha256sum -c -
echo "bf27d43b93345614ef33377434112e8be654b445cd89f64ba708fe6107cb48e6  CHECKPOINT_2.md" | sha256sum -c -
echo "8221db40fb40e93f7539dd4234b0cc5b2cb7c45338c8576de3ec0da21f11293c  SOURCE_PROVENANCE.md" | sha256sum -c -
cd "$PROJECT_ROOT/logs"
sha256sum -c *.sha256
```

Expected: every line ends with `OK`. If any check fails, stop.

## 2. Commit the reviewed G09 work (local only, UTC)

```bash
cd "$PROJECT_ROOT"
cp "$DOWNLOAD_DIR/G09_review.md" logs/review/
cp "$DOWNLOAD_DIR/CHECKPOINT_2.md" logs/review/
cp "$DOWNLOAD_DIR/SOURCE_PROVENANCE.md" docs/
git add scripts/G09_hypervisor.sh docs/G09_hypervisor.md docs/SOURCE_PROVENANCE.md
git status --short
git diff --cached --quiet || TZ=UTC0 git commit -m "G09: hypervisor image (make hypervisor); checkpoint 2"
git log -1 --format='%h  %aI  %an <%ae>  %s'
git show --stat --format= HEAD
cp "$DOWNLOAD_DIR/G10_firmware.sh" scripts/
cp "$DOWNLOAD_DIR/G10_firmware.md" docs/
```

The commit contains the G09 script and document (revision 2) and `docs/SOURCE_PROVENANCE.md`, which now records the
Linux source built from kernel.org Git, Bootlin's toolchain, and the nested QEMU.

## 3. Record the host and source state, and check memory and disk

```bash
uname -r
free -h
df -h "$PROJECT_ROOT"
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
git status --short
test "$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)" -ge 4194304
test "$(df -BG --output=avail "$PROJECT_ROOT" | tail -n 1 | tr -dc '0-9')" -ge 10
```

The last two lines fail if less than 4 GiB of memory or less than 10 GB of disk is available.

## 4. Set the build environment

```bash
source "$PROJECT_ROOT/scripts/build_env.sh"
env | grep -E '^(ACE_DIR|QEMU_SOURCE_DIR|BR2_DL_DIR|CARGO_HOME|BR2_JLEVEL|OMP_NUM_THREADS|CARGO_BUILD_JOBS|WGETRC)=' | sort
```

## 5. Record the compiler Buildroot used for the hypervisor (G09 follow-up)

```bash
GCC_BR="$(find "$ACE_DIR/hypervisor/buildroot" -maxdepth 7 -path '*/bin/*-linux-gnu-gcc' -print -quit)"
echo "$GCC_BR"
"$GCC_BR" --version
grep -a -o -m 1 'Linux version [[:print:]]*' "$ACE_DIR/hypervisor/buildroot/images/Image"
```

G09 could not record the version of Bootlin's compiler (G09 review F5). The first lines find it anywhere in the Buildroot
tree; the last line reads the version banner compiled into the hypervisor kernel, which names the compiler that built it.
These lines only record information.

## 6. Check the Rust toolchain and the payload before the build

```bash
cd "$PROJECT_ROOT/upstream/ACE-RISCV/security-monitor"
echo "RUSTUP_TOOLCHAIN=${RUSTUP_TOOLCHAIN:-<not set>}"
rustup show active-toolchain
rustc --version
cargo fmt --version
rustup target list --installed
git -C opensbi status --short
grep -c ace_setup_this_hart opensbi/lib/sbi/sbi_hsm.c || echo "(OpenSBI not patched)"
test "$(sha256sum < "$ACE_DIR/hypervisor/buildroot/images/Image" | cut -d' ' -f1)" = 75a0db25e8f28f415d93b490bbaf4f1bf4b31b6c22685556bfe32adf056308d7
```

Expected: `RUSTUP_TOOLCHAIN` is not set (it was used only for the TAP tool in G07), so `rust-toolchain.toml` selects
`nightly-2026-03-23` with `rustfmt` and the target `riscv64gc-unknown-none-elf`. The OpenSBI submodule is still unpatched
(the Makefile's own test is the marker `ace_setup_this_hart` in `lib/sbi/sbi_hsm.c`). The last line fails unless the payload
is exactly the hypervisor kernel reviewed in G09.

## 7. Build the firmware with the upstream Makefile

```bash
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
date -u
make -j2 firmware
date -u
```

This is the upstream procedure (`Makefile:73-74`). In order: OpenSBI bindings (`rust-crates/opensbi.sh`), `cargo fmt`,
`cargo build` of the security monitor, then the OpenSBI patch and the OpenSBI build with the payload. The `hypervisor`
prerequisite is skipped because its root file system exists.

## 8. Verify the firmware and the security monitor

```bash
FW="$ACE_DIR/security-monitor/opensbi/platform/generic/firmware"
ls -l "$FW"
file "$FW/fw_payload.elf"
sha256sum "$FW/fw_payload.elf" "$FW/fw_payload.bin"
ls -l "$ACE_DIR/security-monitor/libace.a"
sha256sum "$ACE_DIR/security-monitor/libace.a"
```

The SHA-256 of `fw_payload.elf`, `fw_payload.bin`, and `libace.a` are recorded for E2.

## 9. Check that the firmware carries the G09 hypervisor kernel

```bash
python3 -c 'import sys; fw = open(sys.argv[1], "rb").read(); img = open(sys.argv[2], "rb").read(); i = fw.find(img); print("payload offset:", hex(i) if i >= 0 else "NOT FOUND"); sys.exit(i < 0)' "$FW/fw_payload.bin" "$ACE_DIR/hypervisor/buildroot/images/Image"
```

This searches `fw_payload.bin` for the exact bytes of the hypervisor kernel and prints where they start. A found offset
shows that the firmware embeds the kernel whose hash was checked in step 6, without assuming the payload offset of ACE's
OpenSBI platform.

## 10. Record the crates that were downloaded

```bash
find "$CARGO_HOME/registry/cache" -name '*.crate' | wc -l
find "$CARGO_HOME/registry/cache" -name '*.crate' -printf '%f\n' | sort
```

The list now contains the crates of the TAP tool (57, G07) and of the security monitor (`security-monitor/Cargo.lock`).

## 11. Record the changes the build made to the upstream tree

```bash
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
git status --short
git diff --stat
git -C security-monitor/opensbi status --short
git -C security-monitor/opensbi diff --stat
grep -c ace_setup_this_hart security-monitor/opensbi/lib/sbi/sbi_hsm.c
cd "$PROJECT_ROOT"
git status --short
free -h
df -h "$PROJECT_ROOT"
```

Expected: the superproject shows the 5 patched files and the OpenSBI submodule as modified; any other change in
`security-monitor/` was made by `cargo fmt` and is listed by `git diff --stat`. Inside the submodule, the changes are those
of `opensbi_v1.4.patch`, and the marker is now present. The project shows only the two new G10 files.

## 12. Run all steps with logging

```bash
bash scripts/G10_firmware.sh
```

On the first run, use the downloaded copy: `bash ~/download/G10_firmware.sh`.
The script stops after step 1, 2, 3, 4, 6, or 7 if a check failed, and still seals the log.
