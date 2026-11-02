# Patches to the upstream sources

The IBM ACE-RISCV sources in `upstream/ACE-RISCV` are never edited by hand.
Every change is a patch in this folder, applied and logged by a gate script (G05b).

| Patch | Files | Reason |
|---|---|---|
| `0001-build-parallelism.patch` | `hypervisor/Makefile`, `confidential-vms/linux_vm/Makefile`, `security-monitor/Makefile` | make the build respect a job limit (`-j2` on the shared host) |
| `0002-run-scripts-host-safety.patch` | `tools/ace_run_hypervisor.sh`, `tools/common.sh` | SSH only on 127.0.0.1; never stop other users' or projects' processes; nothing written to `~/.ssh` |

Base commit: IBM/ACE-RISCV `1ebdebf4cacc04fcb83191053b4e979cbcdcb2d6`.
The full reasoning, with file and line references, is in `docs/SAFETY_AUDIT.md`.

Apply from the upstream checkout:

```bash
cd upstream/ACE-RISCV
git apply ../../patches/0001-build-parallelism.patch
git apply ../../patches/0002-run-scripts-host-safety.patch
```

The patches modify files of IBM ACE-RISCV, which is licensed under the Apache License 2.0;
the patches are provided under the same license.
