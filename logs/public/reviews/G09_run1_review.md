# G09 Review, first run: Build the RISC-V Linux Hypervisor Image (`make hypervisor`)

| Field | Value |
|---|---|
| Gate | G09 Hypervisor, first run |
| Run | `G09_20261102T114120Z_PLjTHu` |
| Input script SHA-256 | `50edd11b5e872409845173351cd3bee5a4f7cf717487f14d2fb05190e7e24851` |
| Raw log SHA-256 | `4533cc5e073b92ef850be63d0aac92949fb5d8d339463aff16f9b01f4c65c4eb` |
| Reviewed material | masked review log (262 lines) |
| Previous gate | G08 PASS |
| **Judgement** | **BLOCKED** (an external download failed; nothing in the project or upstream tree is wrong) |

## What happened

| Step | Result |
|---|---|
| 1-2 | inputs OK; G08 committed (`f949474`) |
| 3 | 7.3 GiB memory, 473 GB disk available: both checks passed |
| 4 | the 8 build variables in effect |
| 5 | Buildroot started with `BR2_JLEVEL=2` and `O=` outside the checkout; 45 of the 46 sources downloaded; the download of `linux 6.3-rc4` failed: `make[3]: *** [package/pkg-generic.mk:179: .../build/linux-6.3-rc4/.stamp_downloaded] Error 1`. Stopped after 3 min 29 s (11:41:20-11:44:49 UTC), while `host-tar` was being configured. |

Buildroot's download helper runs `wget` quietly, so the log does not show the server's answer.

## Cause

For a Linux release candidate, Buildroot 2023.11 does not use the kernel.org release directory; it downloads a
snapshot that cgit generates on demand: `LINUX_SITE = https://git.kernel.org/torvalds/t`, file `linux-6.3-rc4.tar.gz`
(`linux/linux.mk`). This endpoint is not reliable for automated tools today: git.kernel.org is now behind a
proof-of-work bot protection (Anubis), and requests for `/torvalds/t/linux-<rc>.tar.gz` have also been reported to return
"Unsupported snapshot format". Which of the two applied on this host is recorded by the next run. The Buildroot backup
site (`sources.buildroot.net`) evidently did not have the file either.

Git access to the same server works: G05 read `git.kernel.org` repositories over HTTPS and `git://`.

## Decision

Build the same source, `v6.3-rc4` of Linus Torvalds' tree, from kernel.org's Git service instead of the cgit snapshot,
and place it where Buildroot looks before downloading (`$BR2_DL_DIR/linux/linux-6.3-rc4.tar.gz`):

1. Shallow-clone tag `v6.3-rc4` from `https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git`.
2. Create `linux-6.3-rc4.tar.gz` with `git archive --prefix=linux-6.3-rc4/`, which is how cgit creates its snapshots.
3. Verify that the commit embedded in the tarball equals the commit that the tag points to on kernel.org and on the
   GitHub mirror (two independent sources).

This changes where the bytes come from, not what is built: no upstream file is modified, and Buildroot has no hash for
a custom kernel version in any case (G05b review F5). The commit check is stronger evidence than the unverified cgit
download would have been. The confidential VM's Buildroot (G11) uses the same download directory and file.

## Correction of an earlier review

**G06 review F1 was wrong.** It assumed that Buildroot would use the RISC-V GNU toolchain from G06 and check it against
the declared GCC 12 / headers 5.10. The Buildroot configurations set `BR2_TOOLCHAIN_EXTERNAL=y` but do not select a
custom toolchain, so Buildroot takes its default external toolchain for RISC-V, **Bootlin's prebuilt toolchain
2023.08-1**, which appears in the download list of this run. The toolchain from G06 is used for OpenSBI, the security
monitor, and kvmtool; the hypervisor and confidential-VM kernels and root file systems are built with Bootlin's
toolchain, as in the upstream CI, which uses the same configuration. The next run records that toolchain's version and
the SHA-256 of its download; `docs/SOURCE_PROVENANCE.md` will be corrected after G09.

## Next

G09, second run: record the cgit response, build the Linux tarball from kernel.org Git and verify it, then run
`make hypervisor` again. Buildroot restarts from the beginning (`hypervisor/Makefile:39`), but the 45 downloads in
`build/dl` are reused.
