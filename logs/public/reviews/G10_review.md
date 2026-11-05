# G10 Review: Build the Firmware: OpenSBI with the ACE Security Monitor (`make firmware`)

| Field | Value |
|---|---|
| Gate | G10 Firmware |
| Run | `G10_20261102T131021Z_RbQpnI` |
| Input script SHA-256 | `fe39133881948eb8da176bd957d1c83b334aa2c28a2a394d69b12b4f6a2d2e70` |
| Raw log SHA-256 | `fb35759d914d66b3569a25e598a0cdf5cb6e1d30b692d250956c900545ee9053` |
| Reviewed material | masked review log (1,509 lines) |
| Previous gate | G09 PASS; checkpoint 2 recorded |
| **Judgement** | **PASS** (E2: security monitor and firmware built; the firmware is shown to carry the reviewed hypervisor kernel) |

## Criteria

| Criterion | Evidence (step) | Result |
|---|---|---|
| Inputs and evidence intact | 3 hash checks OK; all sealed files OK (1) | OK |
| G09 work committed in UTC | `08fca23`, 3 files (G09 rev. 2, SOURCE_PROVENANCE) (2) | OK |
| Memory and disk | 8,995,800 kB available; 466 GB free (3) | OK |
| Bootlin compiler recorded (G09 F5) | `riscv64-buildroot-linux-gnu-gcc ... 13.2.0` under `per-package/toolchain/host/opt/ext-toolchain/bin/`; the kernel banner names `riscv64-linux-gcc ... 13.2.0, GNU ld (GNU Binutils) 2.41` (5) | OK |
| Rust toolchain for the security monitor | `RUSTUP_TOOLCHAIN` not set; `nightly-2026-03-23` (`rustc 1.96.0-nightly (562dee482 2026-03-21)`), `rustfmt 1.9.0-nightly`, target `riscv64gc-unknown-none-elf` (6) | OK |
| OpenSBI unpatched before the build | submodule clean; marker count 0 (6) | OK |
| Payload is the reviewed kernel | SHA-256 of `Image` = `75a0db25...08d7` (6) | OK |
| `make -j2 firmware` succeeded | 20 s (13:10:21-13:10:41 UTC); no error; security monitor `Finished release in 10.80s` (7) | OK |
| Job limit effective | three `make[2]: warning: -j2 forced in submake` messages (OpenSBI builds with `-j$(shell nproc)` and `OMP_NUM_THREADS=2`) (7) | OK |
| Firmware and security monitor | `fw_payload.elf` 23,743,600 bytes, RISC-V 64-bit static-pie ELF, SHA-256 `6a41b58184c3f25db92b036635abf9738df2a4b375e63c58100e313473b8c286`; `fw_payload.bin` 24,128,008 bytes, SHA-256 `412348080fb77dfb0e3c08738d201c6ec2bdab09fa8acd7afc1d2ef540fea281`; `libace.a` 7,645,364 bytes, SHA-256 `2f3e87b7425424fed1830a73b3cf92d09f754bb549987058f0f0e084c610bd76` (8) | OK |
| Firmware carries the G09 kernel | the exact bytes of `Image` found in `fw_payload.bin` at offset `0x200000` (9) | OK |
| Crates recorded | 84 crate files (57 TAP tool, 27 security monitor) (10) | OK |
| Changes to the upstream tree | superproject: the 5 patched files and `m security-monitor/opensbi`, nothing else, so `cargo fmt` changed nothing; submodule: `lib/sbi/sbi_hart.c` (6 lines), `lib/sbi/sbi_hsm.c` (+7), marker count 2 (11) | OK |

## Findings and actions

**F1. The Bootlin compiler is GCC 13.2.0.** It reports itself as built with Buildroot `2021.11-8547-g7e65a1a` (the Buildroot
tree Bootlin used to produce toolchain release 2023.08-1), and the hypervisor kernel's banner confirms that this compiler and
GNU ld 2.41 built it. G09 F5 is closed. The hypervisor and confidential-VM kernels and root file systems are built with
GCC 13.2.0 (Bootlin); OpenSBI, the security monitor's C parts, and kvmtool with GCC 12.2.0 (G06 toolchain).

**F2. The payload sits at offset 0x200000**, the standard payload offset of 64-bit OpenSBI. The firmware that G13 boots
therefore contains exactly the kernel reviewed in G09.

**F3. The upstream build changed only what its design says.** `cargo fmt` left the security monitor's sources unchanged;
the OpenSBI submodule carries the changes of `security-monitor/platform/opensbi_v1.4.patch` (SAFETY_AUDIT A11). The
submodule stays patched; `make firmware` reverses and re-applies the patch on each run (`security-monitor/Makefile:54-68`).

**F4. OpenSBI is built three times.** `rust-crates/opensbi.sh` builds and installs the unpatched OpenSBI to generate the
Rust bindings, and the `opensbi` target then builds the patched OpenSBI with the security monitor and payload. All builds
used 2 jobs. No action.

**F5. Swap use on the host has grown** (2.5 GiB used), while 8.6-9.7 GiB of memory remained available. Other workloads cause
this; the memory check before each build gate remains in place. No action.

## Next

G11: `make confidential_vms` (the confidential VM's kernel and root file system, `ace.ko`, the TAPs, kvmtool and dtc, and a
repacked hypervisor root file system). The upstream sequence leaves a known gap that G12 closes (see the G11 document).
