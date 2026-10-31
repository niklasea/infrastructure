# Backup

The role renders one script per entry in `backup_jobs` to
`/usr/local/sbin/backup-<name>.sh` and schedules it with cron.

## Job fields

- `name` — script and cron job name.
- `mount` — optional mountpoint that must be mounted before the job runs.
- `schedule` — five-field cron expression; for example `0 4 * * *`.
- `commands` — shell commands to run; the first failure aborts the job.
- `cleanup` — optional commands that run on exit, including on failure.

## Behaviour

Each run gets a private staging directory in `/var/tmp`, available as
`${tmpdir}` in `commands` and `cleanup`. The directory is removed on exit, and
INT/TERM are trapped so cleanup runs on interruption. Callers should write the
backup to a temporary file on the target share and rename it into place after
verifying it. Failures are logged to syslog with the `backup[<name>]` tag.

Restore instructions live with the service that owns the data.
