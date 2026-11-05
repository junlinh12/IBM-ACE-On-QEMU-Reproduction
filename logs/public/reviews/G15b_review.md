# G15b Review: Negative Control of the Local Attestation

| Field | Value |
|---|---|
| Gate | G15b Negative Control (added at the owner's decision after checkpoint 3) |
| Run | `G15b_20261104T130510Z_X7qKqK` |
| Input script SHA-256 | `c34d7e0a39d0af267aad403dd9d5c4e393e358fc3cf03091dc01e896e058fe7c` |
| Raw log SHA-256 | `2e5ae0ecb49c8167283e91c4ae3791ec61a2b691ad0898bbe619c546edee3637` |
| Console logs (private, sealed through this gate's log) | platform `logs/G15b_hypervisor_serial_20261104T130510Z.log` (`5e030167...`); VM, negative run `logs/G15b_tvm_console_negative_20261104T130510Z.log` (`920ce0e0...`); VM, positive run `logs/G15b_tvm_console_positive_20261104T130510Z.log` (`6c07f72f...`) |
| Reviewed material | masked review log (406 lines) |
| Previous gate | G15 PASS |
| **Judgement** | **PASS** (with a wrong reference value in the TAP the secret was not released; with the original TAP, in the same boot, it was) |

## Criteria

| Criterion | Evidence (step) | Result |
|---|---|---|
| Inputs and evidence intact; G15 committed | hash checks OK; G15 commit (1, 2) | OK |
| Host ready; reviewed images | >= 6 GiB, port free, no QEMU of this project; `fw_payload.elf` `6a41b581...`, disk `cc07c2dc...` (3, 4) | OK |
| VM kernel still measures to the correct value | `cove-tap-tool measure` = `0x4e73d007...da33` (5) | OK |
| Wrong TAP generated as upstream | `cove-tap-tool generate --pcrs 4=0x4e73d007...da34 --secrets 0=0xc0ffeec0ffeec0ffeec0ffee`; tool output `Writing PCR4=...da34`, `Writing secret 0`; 1,756 bytes (the size of the original), SHA-256 `bc2f56edc924af6b2ef6374707357867697206a7082e25c841e1e16e8dd3bdf2` (5) | OK |
| Wrong TAP in place | original `1c28e899...` kept; the file at `/root/linux_vm/cove_tap_qemu` equals the host's wrong TAP (`bc2f56ed...`) (7) | OK |
| **Negative run** | nested QEMU loaded the TAP at `0x81503000`; security monitor: measured `PCR4=...da33`, `Reference PCR4=Sha3_256=0x...da34`, **`#ACE: Local attestation failed: LocalAttestationFailed`**, then `Created new confidential VM[id=ConfidentialVmId(0)]`; the VM booted; after `insmod ace.ko` only `Requesting secret from the security monitor`; secret lines = **0** (8) | OK |
| Original TAP restored exactly | `cmp` silent; SHA-256 = `1c28e899...` (the G12 TAP) (9) | OK |
| **Positive run** | measured `PCR4=...da33`, `Reference PCR4=...da33`, **`#ACE: Attestation succeeded, fetched 1 secrets`**; `Secret=0xc0ffeec0ffeec0ffeec0ffee`; secret lines = **1** (10) | OK |
| **Judgement of the experiment** | negative: secret lines 0, `Attestation succeeded` 0; positive: secret lines 1, `Attestation succeeded` 1 (all four `test` lines hold) (11) | OK |
| Clean shutdown; logs sealed; disk restored | run script exit 0 at 13:05:59; no QEMU left; three console logs read-only and hashed; disk `6e673ca5...` after the run, pristine `cc07c2dc...` restored (12, 13) | OK |

## Findings and actions

**F1. The release of the secret depends on the comparison of measurement and reference.** In one hypervisor boot, with the same VM
kernel, disk, and run script, the security monitor measured the same PCR 4 both times. Changing only the TAP's reference value in its last
hex digit turned `Attestation succeeded, fetched 1 secrets` into `Local attestation failed: LocalAttestationFailed`, and the VM received no
secret. Together with G14 (F1) this completes the evidence for E6 and E7: the secret is released if and only if, in these two cases, the
reference matches the measurement.

**F2. A failed attestation does not stop the VM.** The security monitor still created and ran the confidential VM after the failed
attestation; it only withheld the secrets. The VM's module printed `Requesting secret from the security monitor` and then nothing, so a VM
cannot tell a failed attestation from other errors by this module's output. This is the behaviour of the pinned commit, recorded for the
report.

**F3. The security monitor reports the VM's memory layout.** `kernel: (2147483648, 2415919104)` = `0x80000000-0x90000000` (256 MiB),
`fdt` at `0x8fe00000`, `initrd: None`, 1 confidential hart. These are the VM's guest-physical addresses; the host-physical placement in
confidential memory is not printed.

**F4. Scope.** One wrong value differing in 4 bits was tested. The result shows the dependence of the release on the measurement; it is
not a test of the cryptographic protection of the TAP or of attacks against it.

## Next

G16a: read-only publication audit of everything Git would publish and of the whole Git history (E9). The fixes follow in G16b, after the
owner's decisions on the license, the scope of published evidence, and the GitHub repository.
