# Publication

What this repository publishes, what it keeps private, and how the published material was checked (charter 4.4, success criterion E9).
Prepared in G16a (audit) and G16b (preparation); pushed in G17.

## Owner's decisions

| Question | Decision |
|---|---|
| License | Apache License 2.0, as upstream ([`LICENSE`](../LICENSE), [`NOTICE`](../NOTICE)) |
| Published evidence | scripts, documents, gate reviews, checkpoints, and sanitized review logs |
| GitHub repository | created as private; the owner reviews it on GitHub and then makes it public |

## Published and private material

| Published | Private (never committed) |
|---|---|
| `scripts/`, `docs/`, `patches/`, `PROJECT_CHARTER.md`, `README.md`, `LICENSE`, `NOTICE`, `.gitignore` | `upstream/`: IBM's repository and its submodules |
| `logs/public/reviews/`: gate reviews and checkpoints, sanitized | `build/`: all build output, which embeds the host's paths and names |
| `logs/public/review-logs/`: the review copies of all gate logs, sanitized | `logs/*.raw.log`, `logs/*.input.sh`, `logs/*.sha256`: the sealed originals |
| `logs/public/SHA256SUMS`, `ORIGINALS.sha256`, `COMMIT_MAP.txt` | `logs/*_serial_*.log`, `logs/*_tvm_console_*.log`: console logs with build banners naming the host |
| | `logs/review/`: the unsanitized review copies |
| | `logs/G16b_pre_rewrite_*.bundle`: the history before G16b |

`.gitignore` excludes everything under `logs/` except `logs/public/` (G01).

## Sanitization

The logging harness masks every review copy: the user name, the host name, and the home path are replaced (`<user>`, `<host>`, `~`).
The published copies go through a second step, [`scripts/sanitize_evidence.sh`](../scripts/sanitize_evidence.sh), which replaces:

| Information | Replacement |
|---|---|
| timestamps written with the host's local UTC offset (ISO and `git log` forms, `date` with the zone abbreviation) | `<local time>` |
| the host's local UTC offset in both forms | `<local offset>` |
| the host's zone abbreviation and zone name | `<local zone>` |
| `timedatectl`-style lines (`Local time`, `Time zone`, `RTC ...`) | `<removed>` |
| apt history lines (`Start-Date`, `End-Date`, `Requested-By`) | `<removed>` |
| `ls`-style times in the logs of G00-G07, written before the harness printed UTC (SAFETY_AUDIT A17) | `<local time>` |

The script reads the offset, the zone abbreviation, and the zone name at run time, so it contains none of them; the same holds for every
other script in this repository. The published copies keep their file names. `ORIGINALS.sha256` lists the SHA-256 of the private review
copies, and each review copy ends with `masked_from_raw_sha256=...`, the SHA-256 of its sealed raw log, so every published log can be
traced to its sealed original by its owner.

The copies of the G16a script and document were changed in the same way: as run, they searched for the local offset as a literal string;
the committed copies read it at run time (G16a review F6). The executed script stays sealed in `logs/`.

## History

Before publication the history was rewritten once, in G16b, after a complete backup to a private Git bundle:

- every author and committer date was set to `+0000`, keeping its instant; before, the root commit carried the host's local offset;
- one sentence of `docs/G03_apt_packages.md` that named the offset was replaced in every commit that contained it.

No other content changed. The rewrite changed all commit hashes; [`logs/public/COMMIT_MAP.txt`](../logs/public/COMMIT_MAP.txt) maps the
hashes cited in the reviews to the published ones.

## Checks before the push

G16b audits the result in the same way as G16a: the whole history and the published evidence are searched for the user name, the host
name, the home path, `/home/`, the local offset in both forms, the zone abbreviation and name, apt history details, private keys and
tokens, and non-loopback addresses outside the emulated network. Checkpoint 4 re-checks the main task and the requirements, and G17
repeats the search immediately before the push.

## Approval

G17 pushes to the private repository only. The owner reviews it on GitHub and makes it public; no gate does that.
