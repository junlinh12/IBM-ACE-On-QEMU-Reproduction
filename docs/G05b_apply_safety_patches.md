# G05b: Apply the Safety Patches

The read-only audit (G05, `docs/SAFETY_AUDIT.md`) found that the upstream build ignores the job limit
and that the run scripts expose the guest's SSH port on the network and can kill other projects'
processes. This second G05 run records the remaining evidence (the test scripts and Buildroot
configurations) and then applies two patches to the upstream checkout, with logging.
Nothing is built or run.

Previous gate: **G05 read-only audit PASS** (see `logs/review/G05_review.md`).

The same commands are run, with logging, by [`scripts/G05b_apply_safety_patches.sh`](../scripts/G05b_apply_safety_patches.sh).

| Patch | Effect | Findings |
|---|---|---|
| `patches/0001-build-parallelism.patch` | Buildroot jobs and two `make -j` calls follow a job limit | A1, A2 |
| `patches/0002-run-scripts-host-safety.patch` | SSH on 127.0.0.1 only; stop only ACE's own QEMU; nothing written to `~/.ssh` | A5, A7, A8, A9 |

Set the paths first:

```bash
PROJECT_ROOT=~/projects/IBM-ACE-On-QEMU-Reproduction
DOWNLOAD_DIR=~/download
```

## 1. Verify the downloaded files and all sealed evidence

```bash
cd "$DOWNLOAD_DIR"
sha256sum G05b_apply_safety_patches.sh G05b_apply_safety_patches.md
echo "770d636225cc42ba9954513dfcb426db343131c49b68761db2b9ebb562db8956  G05_review.md" | sha256sum -c -
echo "4c2de2f2ffec80da8639932f292510dcd1f44f358f3373fd9ee2a9083fb8fe38  SAFETY_AUDIT.md" | sha256sum -c -
echo "8ce96558b74c5019087e8cc79f166d534dbb40fa67cfe88426c8fdef063cf7e5  PATCHES_README.md" | sha256sum -c -
echo "cf83fb0b058c47958b9767be45673780ecd34de044bc89cf723fe4dcbe68f69a  0001-build-parallelism.patch" | sha256sum -c -
echo "2aeadce13855d1d518ec267d2f5ee9f6164849751583495c022e2f1fd0faf503  0002-run-scripts-host-safety.patch" | sha256sum -c -
cd "$PROJECT_ROOT/logs"
sha256sum -c *.sha256
```

Expected: every line ends with `OK`. If any check fails, stop.

## 2. Commit the reviewed G05 read-only work (local only, UTC)

```bash
cd "$PROJECT_ROOT"
cp "$DOWNLOAD_DIR/G05_review.md" logs/review/
git add scripts/G05_audit_build_scripts.sh docs/G05_audit_build_scripts.md
git status --short
git diff --cached --quiet || TZ=UTC0 git commit -m "G05: audit upstream build and run scripts (read-only)"
git log -1 --format='%h  %aI  %an <%ae>  %s'
git show --stat --format= HEAD
cp "$DOWNLOAD_DIR/G05b_apply_safety_patches.sh" scripts/
cp "$DOWNLOAD_DIR/G05b_apply_safety_patches.md" docs/
```

## 3. Record the test scripts and Buildroot configurations

```bash
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
git ls-files -z -- hypervisor/rootfs confidential-vms/linux_vm/hypervisor_rootfs | xargs -0 -r grep -IHn ''
grep -IHn '' hypervisor/configurations/qemu_riscv64_virt_defconfig confidential-vms/linux_vm/configurations/qemu_riscv64_virt_defconfig
```

The first command records the scripts that run inside the emulated hypervisor: the self test, the
attestation test, and the scripts that start the confidential VM. They define the test output that E8 is
judged on. The second records the Buildroot configurations, which select the Linux version and the
packages that Buildroot downloads (E1). These files exist at the pinned commit (G05, step 4);
if one is missing, stop, because the sources are not the audited ones.

## 4. Install the patches and the audit into the project

```bash
cd "$PROJECT_ROOT"
cp "$DOWNLOAD_DIR/0001-build-parallelism.patch" patches/
cp "$DOWNLOAD_DIR/0002-run-scripts-host-safety.patch" patches/
cp "$DOWNLOAD_DIR/PATCHES_README.md" patches/README.md
cp "$DOWNLOAD_DIR/SAFETY_AUDIT.md" docs/
sha256sum patches/*
```

## 5. Check the patches against the pinned sources

```bash
cd "$PROJECT_ROOT/upstream/ACE-RISCV"
git rev-parse HEAD
git ls-tree HEAD hypervisor/Makefile confidential-vms/linux_vm/Makefile security-monitor/Makefile tools/ace_run_hypervisor.sh tools/common.sh
git apply --reverse --check "$PROJECT_ROOT/patches/0001-build-parallelism.patch" 2>/dev/null || git apply --check "$PROJECT_ROOT/patches/0001-build-parallelism.patch"
git apply --reverse --check "$PROJECT_ROOT/patches/0002-run-scripts-host-safety.patch" 2>/dev/null || git apply --check "$PROJECT_ROOT/patches/0002-run-scripts-host-safety.patch"
```

`git ls-tree` prints the Git object ID of each file at the pinned commit. The patches were written against
copies of these files reconstructed from the G05 log; matching object IDs prove that the copies were exact.

Each `git apply` line reads: if the patch is already applied (a re-run), accept that; otherwise check that
it applies cleanly. If a check fails, stop: the sources are not the audited ones.

## 6. Apply the patches

```bash
git apply --reverse --check "$PROJECT_ROOT/patches/0001-build-parallelism.patch" 2>/dev/null || git apply "$PROJECT_ROOT/patches/0001-build-parallelism.patch"
git apply --reverse --check "$PROJECT_ROOT/patches/0002-run-scripts-host-safety.patch" 2>/dev/null || git apply "$PROJECT_ROOT/patches/0002-run-scripts-host-safety.patch"
git apply --reverse --check "$PROJECT_ROOT/patches/0001-build-parallelism.patch"
git apply --reverse --check "$PROJECT_ROOT/patches/0002-run-scripts-host-safety.patch"
```

The first two lines apply each patch once (they skip a patch that is already applied).
The last two confirm that both patches are now in place.

## 7. Record the patched state

```bash
git status --short
git diff --stat
git diff
grep -n 'BR2_JLEVEL\|nproc' hypervisor/Makefile confidential-vms/linux_vm/Makefile security-monitor/Makefile
OMP_NUM_THREADS=2 nproc
```

Expected: exactly 5 modified files; `BR2_JLEVEL=$(BR2_JLEVEL)` and `-j$(shell nproc)` in the recipes;
`OMP_NUM_THREADS=2 nproc` prints `2`, which is how the build will limit `nproc` (A2, A3).

## 8. Check the project repository

```bash
cd "$PROJECT_ROOT"
git status --short
```

Expected: the new G05b files, `patches/`, and `docs/SAFETY_AUDIT.md` are untracked.
They are committed after this gate is reviewed.

## 9. Run all steps with logging

```bash
bash scripts/G05b_apply_safety_patches.sh
```

On the first run, use the downloaded copy: `bash ~/download/G05b_apply_safety_patches.sh`.
The script stops after step 1, 2, 3, 4, 5, or 6 if a check failed, and still seals the log.
