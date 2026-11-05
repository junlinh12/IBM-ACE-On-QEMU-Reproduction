# G14 Review: Confidential VM, Local Attestation, and the Demo Secret

| Field | Value |
|---|---|
| Gate | G14 Attestation |
| Run | `G14_20261104T123248Z_16kjwp` |
| Input script SHA-256 | `c3ab16b4c91c8afbd4155e63e5102697c55e99fa052cfcc06aa73c5e8199067a` |
| Raw log SHA-256 | `f900659f6a7d894acd8e9228f08ecba345756af424be9b5bf1485d6ea7c17639` |
| Console logs (private, sealed through this gate's log) | platform: `logs/G14_hypervisor_serial_20261104T123249Z.log`, 20,890 bytes, SHA-256 `4111ae9c823fd3dbf71f4aca014eb07e0e4c3b2e08b93e8cb1c1bbafa6dcc25f`; confidential VM: `logs/G14_tvm_console_20261104T123249Z.log`, 208 lines, 13,784 bytes, SHA-256 `7834f4c26a604b04d75c454fea9f2472f1df3ab6d246305b0059d89f2f148434` |
| Reviewed material | masked review log (520 lines) |
| Previous gate | G13 PASS |
| **Judgement** | **PASS** (E5: the confidential VM ran as a CoVE TVM under KVM; E6: the security monitor measured it and matched the TAP's reference value; E7: the demo secret was released to the VM, exactly once) |

## Criteria

| Criterion | Evidence (step) | Result |
|---|---|---|
| Inputs and evidence intact; G13 committed | hash checks OK; `4faa6fe` (1, 2) | OK |
| Host ready; reviewed images | >= 6 GiB, port free, no QEMU of this project; `fw_payload.elf` `6a41b581...`, pristine and disk `cc07c2dc...` (3, 4) | OK |
| Hypervisor up | QEMU with `hostfwd=tcp:127.0.0.1:4022-:22`; SSH at 12:32:54, 5 s after the start (5, 6) | OK |
| **E5: TVM created with KVM and CoVE** | nested QEMU `--enable-kvm -machine virt,cove=true,cove-tap-filename=/root/linux_vm/cove_tap_qemu -cpu rv64,f=true -smp 1 -m 256M`; `warning: Creating CoVE TVM`; `Register kernel region 80000000 22032384` (the size of the VM `Image`); `Loading CoVE TAP /root/linux_vm/cove_tap_qemu 81503000` (7, 11) | OK |
| **E5: TVM created by the security monitor** | `#ACE: Promoting a VM to a confidential VM`; `#ACE: Created new confidential VM[id=ConfidentialVmId(0)]` (11) | OK |
| **E5: the confidential VM runs** | SSH at 12:33:07 (8 s after the start); `Linux confidential_vm 6.3.0-rc4`, 1 processor, 256 MiB guest memory (151 MiB usable, 64 MiB `swiotlb` bounce buffer); `hello from confidential VM filesystem`; command line `swiotlb=mmnn,force`; banner `Welcome to ACE Confidential VM!` (8, 9, 11) | OK |
| **E6: measurement and reference** | `#ACE: Reading TEE attestation payload (TAP) at memory address 0x81503000`; measured `PCR4=4e73d007ac0f79c9e476f42ead1ad1299cffc44ddd0719c690b368e22040da33`; `#ACE: Reference PCR4=Sha3_256=0x4e73d007...da33`; `#ACE: Attestation succeeded, fetched 1 secrets` (11) | OK, see F1 |
| **E7: secret released** | after `insmod /root/ace_module/ace.ko`: `Requesting secret from the security monitor`, `Secret=0xc0ffeec0ffeec0ffeec0ffee`; count of the secret line = 1 (`test 1 = 1`), the upstream pass criterion (10) | OK |
| VM and hypervisor stopped | `kill_confidential_vm`; `#ACE: Removing ConfidentialVM[ConfidentialVmId(0)] from the control data structure`; `poweroff`, `reboot: Power down`; run script exit 0 at 12:33:20; no QEMU left; port free (11, 12) | OK |
| Logs sealed; disk restored | both console logs read-only, hashed; disk `497d8153...` after the run, pristine `cc07c2dc...` restored (13) | OK |

## Findings and actions

**F1. Three independent values of PCR 4 agree.** The measurement that the security monitor took of the TVM at run time, the reference
value it read from the TAP, and the value computed on the host with `cove-tap-tool measure` in G11 and G12 are all
`0x4e73d007ac0f79c9e476f42ead1ad1299cffc44ddd0719c690b368e22040da33` (SHA3-256). The secret was released after this comparison
succeeded. This is the local attestation that the paper describes, shown on the reproduced system.

**F2. The security monitor reports further measurements.** PCR6 (`dc168ef5...`) and PCR7 (`90d5d644...`) are non-zero; PCR0-3 and PCR5
are zero. The TAP constrains only PCR 4 (`--pcrs 4=...`, `confidential-vms/linux_vm/Makefile:83`). What PCR6 and PCR7 measure is not
determined here; it is recorded for the report.

**F3. The TVM sees a different SBI implementation than the hypervisor.** Inside the VM: `SBI implementation ID=0x1 Version=0x1`; in the
hypervisor: `Version=0x10004` (OpenSBI 1.4). This is consistent with the security monitor answering the TVM's SBI calls itself; it is
an observation, not a proof.

**F4. The run script copies the VM directory into itself.** `run_linux_vm_qemu.sh:49-50` tests `[ ! -f /root/linux_vm${ID} ]` on a
directory (always true) and runs `cp -rf /root/linux_vm /root/linux_vm`, which BusyBox refuses with `cp: recursion detected`. Harmless
for the default ID; an upstream defect, recorded for the report. No patch.

**F5. The nested SSH client prints a host-key notice on every hop** (`Host 'localhost' key accepted unconditionally`), from `ssh -y` in
`hypervisor/rootfs/common.sh:6`. It does not affect the results.

**F6. Timing.** Hypervisor SSH 5 s after the start, TVM SSH 8 s after its start, secret 10.8 s after the TVM's boot; the whole gate ran in
31 s. The upstream tests' 30 s wait is sufficient on this host.

## Next

Checkpoint 3 (15 gates completed), then G15: the upstream regression test `ace test`, unchanged (E8).
