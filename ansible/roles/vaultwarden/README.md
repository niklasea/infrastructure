# Vaultwarden

## Backup and restore

The backup job in `main.yml` writes `data.tar.gz` to the configured backup
share. The archive contains the Vaultwarden data directory with a consistent
SQLite snapshot as `db.sqlite3`. The live WAL/SHM/journal files and any old
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
