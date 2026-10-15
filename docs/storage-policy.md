# Local storage policy

`bin/fm-storage-policy.sh` measures the filesystem, reports the 15% alert and 10% large-work refusal thresholds, and treats 30 GiB free as a practical reserve where the volume is large enough.
Run it without options for a dry-run inventory; `--large-work` returns exit status 3 below 10% free, and `--clean` explicitly removes only recognized Go build, uv, and Hugging Face Xet caches that `lsof` confirms are inactive.
A weekly cleanup can be scheduled by the operator with `0 3 * * 0 /absolute/path/to/firstmate/bin/fm-storage-policy.sh --clean`.

Firstmate already gives workers a private `/tmp/fm-<task-id>` temporary root and sets `GOTMPDIR` within it; task cleanup removes that root only after its worker processes are verified stopped.
Do not sweep arbitrary files from `/tmp` or macOS `/private/var/folders`; macOS owns the latter's cleanup policy.
The tool does not manage MLX model storage, Hugging Face model repositories, active worktrees, user files, or unknown temporary files.
It does not cap worktree or model storage, and a full disk can still affect unrelated applications.

The no-mistakes evidence retention limit is configured separately in the user's private `~/.no-mistakes/config.yaml`:

```yaml
test:
  evidence:
    retention: 168h
    max_runs: 50
```

These values retain evidence for at most seven days and 50 runs, whichever limit is reached first.
