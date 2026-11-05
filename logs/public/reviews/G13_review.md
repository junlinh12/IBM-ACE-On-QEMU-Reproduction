# G13 Review: Boot the Emulated RISC-V Platform

| Field | Value |
|---|---|
| Gate | G13 Boot Hypervisor |
| Run | `G13_20261104T111257Z_8tPBjL` |
| Input script SHA-256 | `331fb4ab55deb6ab5ac9fcfbde08341f1716d6d1e2e3c02b70e780728e4f6820` |
| Raw log SHA-256 | `35f813c333a8c9066940dafa0419f1db33ef72c747d18a3fee0efba2623f58a4` |
| Serial log | `logs/G13_hypervisor_serial_20261104T111258Z.log`, 316 lines, 19,528 bytes, SHA-256 `4969849cdff8c53c13c8d943029f570eee5348e63d79669cafedcb855f6d727b` (private; sealed through this gate's log) |
| Reviewed material | masked review log (620 lines) |
| Previous gate | G12 PASS |
| **Judgement** | **PASS** (E3: OpenSBI, the ACE security monitor, and the Linux hypervisor booted; E4: KVM is available in the emulated Linux, with the security monitor detected as its TSM) |

## Criteria

| Criterion | Evidence (step) | Result |
|---|---|---|
| Inputs and evidence intact; G12 committed | hash checks OK; `fd349d8` (1, 2) | OK |
| Host ready | 12,368,812 kB available (>= 6 GiB); port 4022 free; no QEMU of this project running (3) | OK |
| Reviewed images booted | `fw_payload.elf` = `6a41b581...`; `rootfs.ext2` = `cc07c2dc...`; pristine copy made and checked; `rootfs.ext4` -> `rootfs.ext2` (4) | OK |
| QEMU started with the safe forward | command line `... -m 4G -nographic -machine virt -cpu rv64 -bios none -kernel .../fw_payload.elf ...`; `LISTEN 127.0.0.1:4022` only (5) | OK |
| SSH available | `root` at 11:13:03, 5 s after the start (6) | OK |
| **E3: OpenSBI** | `OpenSBI v1.4`; `Platform Name: riscv-virtio,qemu`; 4 harts; `Runtime SBI Version 2.0`; `Domain0 Next Address 0x80200000` (the payload), `Next Mode S-mode` (7) | OK |
| **E3: ACE security monitor** | `#ACE: Initializing the CoVE security monitor`; memory `0x80000000-0x180000000` split into non-confidential `0x80000000-0x100000000` and confidential `0x100000000-0x180000000`; heap and per-hart stacks in confidential memory; for each of the 4 harts: state area, PMP entries for the confidential range, trap handler at `0x80019140` (7) | OK |
| **E3: Linux hypervisor** | `Linux version 6.3.0-rc4 ... Bootlin GCC 13.2.0`; `SBI specification v2.0 detected`; root file system mounted; `Starting dropbear sshd: OK`; banner `Welcome to untrusted Hypervisor!` (7, 10) | OK |
| **E4: KVM in the emulated Linux** | 4 processors; ISA `rv64imafdch...` (hypervisor extension `h`); `/dev/kvm` (char 10,232); `kvm [1]: The platform has confidential computing feature enabled`, `kvm [1]: TSM version 4 is loaded and ready to run`, `kvm [1]: hypervisor extension available`, `using Sv57x4 G-stage page table format`, `VMID 14 bits available` (8) | OK |
| Confidential memory hidden from the hypervisor | the hypervisor sees memory `0x80200000-0xffffffff` only (`lowmem` 2046 MB, `free` 1975 MB); the confidential range above `0x100000000` is not given to Linux (7, 8) | OK |
| Files for G14 present | `/root`: test and run scripts, `lkvm-static`; `/root/linux_vm`: `Image`, `rootfs.ext2`, both TAPs (8) | OK |
| Clean shutdown | `poweroff`; console `kvm: exiting hardware virtualization`, `reboot: Power down`; run script exit 0 at 11:13:09; no QEMU left; port free (9, 10) | OK |
| Disk restored | the guest wrote to its disk (`cc07c2dc...` -> `a5206f50...`); the pristine copy was restored and checked (10) | OK |

## Findings and actions

**F1. The emulated platform boots very fast on this host.** About 0.4 s of kernel time to `/sbin/init`, SSH after 5 s, shutdown
10 s after the start. The upstream test scripts' short time limits (G05b F4) are therefore less of a risk than feared; G14 still
allows more time for the nested confidential VM.

**F2. The security monitor partitions memory before Linux starts.** It reserves the upper half of the 4 GiB
(`0x100000000-0x180000000`) as confidential memory, protects it with PMP entries on every hart, and Linux receives only the lower
half. This is the isolation the confidential VM will run in (G14).

**F3. KVM reports the ACE security monitor as its TSM.** `TSM version 4 is loaded and ready to run` and `The platform has
confidential computing feature enabled` come from the CoVE host patches in the hypervisor kernel (G09) talking to the security
monitor (G10). E4 is shown at the level of device and initialization; G14 shows that KVM actually runs a confidential VM.

**F4. Booting changes the disk image.** The root file system is mounted read-only and then remounted read-write by the init
scripts, so each boot changes `rootfs.ext2`. Restoring the pristine copy after every boot gate keeps the reviewed image as the
starting point of every run.

**F5. The serial log names the build host.** The kernel banner contains `user@host` of the build; the review log masks it. The
serial log stays private (charter 4.4).

## Next

G14: boot the confidential VM inside the hypervisor with KVM and the TAP, run the local attestation (`insmod ace.ko`), and check
that the security monitor released the demo secret (E5, E6, E7). Checkpoint 3 follows G14.
