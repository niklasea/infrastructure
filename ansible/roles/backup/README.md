# Backup

The role installs one script per job at `/usr/local/sbin/backup-<name>.sh` and
schedules it with cron. Each job writes to `<target>.tmp` on the backup share,
verifies the archive, and renames it into place, so a failed run leaves the
previous backup untouched. Failures are logged to syslog with the
`backup[<name>]` tag.

## Restore

### Jellyfin

`jellyfin.tar.gz` contains the Jellyfin configuration directory.

```sh
docker compose -f /etc/compose/jellyfin/docker-compose.yml stop jellyfin
tar -xzf jellyfin.tar.gz -C /
docker compose -f /etc/compose/jellyfin/docker-compose.yml start jellyfin
```

### Gitea

`gitea-dump.zip` is a standard `gitea dump` archive containing the database,
repositories, configuration, and attachments.

```sh
docker compose -f /etc/compose/gitea/docker-compose.yml stop gitea
unzip gitea-dump.zip -d gitea-restore
```

Restore the database, `repos/`, and `data/` contents from the extracted archive
to the Gitea data directory, then start the container:

```sh
docker compose -f /etc/compose/gitea/docker-compose.yml start gitea
```

### Vaultwarden

`data.tar.gz` contains the Vaultwarden data directory plus a consistent SQLite
snapshot named `vaultwarden-db.sqlite3` at the archive root. The live
`db.sqlite3`, its WAL/SHM/journal files, and any old `backup.sqlite3` are
excluded.

```sh
docker compose -f /etc/compose/vaultwarden/docker-compose.yml stop vaultwarden
rm -f /etc/compose/vaultwarden/data/db.sqlite3 \
      /etc/compose/vaultwarden/data/db.sqlite3-wal \
      /etc/compose/vaultwarden/data/db.sqlite3-shm \
      /etc/compose/vaultwarden/data/db.sqlite3-journal
tar -xzf data.tar.gz -C /etc/compose/vaultwarden/data
mv /etc/compose/vaultwarden/data/vaultwarden-db.sqlite3 \
   /etc/compose/vaultwarden/data/db.sqlite3
docker compose -f /etc/compose/vaultwarden/docker-compose.yml start vaultwarden
```

The web vault is not part of this backup; it comes from the image.

### Netbird

`netbird-data.tar.gz` contains the contents of `/var/lib/netbird` from the
`netbird-server` container.

```sh
netbird_compose=/etc/compose/netbird_service/docker-compose.yml
mkdir -p /var/tmp/netbird-restore
tar -xzf netbird-data.tar.gz -C /var/tmp/netbird-restore
docker compose -f "$netbird_compose" stop netbird-server
container_id="$(docker compose -f "$netbird_compose" ps -a -q netbird-server)"
docker cp -a /var/tmp/netbird-restore/. "${container_id}:/var/lib/netbird/"
docker compose -f "$netbird_compose" start netbird-server
rm -rf /var/tmp/netbird-restore
```
