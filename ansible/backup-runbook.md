# Backup runbook

The backup jobs are defined in `main.yml` (Jellyfin, Gitea, Vaultwarden) and
`overlay_networking.yml` (NetBird). Each job writes to the configured SMB
share, verifies the archive, and renames it into place. A failed run leaves the
previous backup untouched.

The target directories are configured through `smb_mounts` in
`host_vars/internal-docker.yml` and `group_vars/role_netbird/vars.yml`.

## Running a backup manually

```sh
sudo /usr/local/sbin/backup-<name>.sh
```

Failures are logged to syslog with the `backup[<name>]` tag:

```sh
journalctl -t 'backup[<name>]'
```

## Restore Jellyfin

`jellyfin.tar.gz` contains the Jellyfin configuration directory.

```sh
docker compose -f /etc/compose/jellyfin/docker-compose.yml stop jellyfin
tar -xzf jellyfin.tar.gz -C /etc/compose/jellyfin/config
docker compose -f /etc/compose/jellyfin/docker-compose.yml start jellyfin
```

## Restore Gitea

`gitea-dump.tar.gz` is a standard `gitea dump` archive containing the database,
repositories, configuration, and attachments.

```sh
docker compose -f /etc/compose/gitea/docker-compose.yml stop gitea
mkdir -p gitea-restore
tar -xzf gitea-dump.tar.gz -C gitea-restore
```

Restore the database, `repos/`, and `data/` contents from the extracted
archive to the Gitea data directory, then start the container:

```sh
docker compose -f /etc/compose/gitea/docker-compose.yml start gitea
```

## Restore Vaultwarden

`data.tar.gz` contains the Vaultwarden data directory with a consistent SQLite
snapshot as `db.sqlite3`. The live WAL/SHM/journal files and any old
`backup.sqlite3` are not included.

```sh
docker compose -f /etc/compose/vaultwarden/docker-compose.yml stop vaultwarden
rm -f /etc/compose/vaultwarden/data/db.sqlite3 \
      /etc/compose/vaultwarden/data/db.sqlite3-wal \
      /etc/compose/vaultwarden/data/db.sqlite3-shm \
      /etc/compose/vaultwarden/data/db.sqlite3-journal
tar -xzf data.tar.gz -C /etc/compose/vaultwarden/data
docker compose -f /etc/compose/vaultwarden/docker-compose.yml start vaultwarden
```

The web vault is not part of this backup; it comes from the image.

## Restore NetBird

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
