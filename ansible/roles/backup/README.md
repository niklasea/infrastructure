# Backup

The role renders one script per entry in `backup_jobs` to
`/usr/local/sbin/backup-<name>.sh` and schedules it with cron.

## Job fields

- `name` — script and cron job name.
- `mount` — backup share path; must be mounted before the job runs.
- `target` — filename within `mount`.
- `schedule` — five-field cron expression; for example `0 4 * * *`.
- `source` — path to archive (directory) or copy (file).
- `pre` — optional commands that create or populate `source`.
- `post` — optional commands that run after a successful save.
- `cleanup` — optional commands that always run on exit.

## Behaviour

The generated script checks the mount, runs `pre`, verifies that `source`
exists and is not an empty directory, then archives it:

- A directory is written to `<target>.tmp` as a gzip-compressed tar archive
  relative to `source`, then verified with `tar -tzf`.
- A file is copied to `<target>.tmp` and verified by extension (`.tar.gz`,
  `.tgz`, `.zip`, or a non-empty check).

The temporary archive is renamed into place only after verification. `post`
runs after the rename, and `cleanup` always runs on exit. Each run gets a
private staging directory in `/var/tmp`, available as `${tmpdir}` in `pre`,
`post`, and `cleanup`; it is removed on exit, and INT/TERM are trapped so
cleanup runs on interruption. Failures are logged to syslog with the
`backup[<name>]` tag.

Restore procedures are in the [backup runbook](../../backup-runbook.md).
