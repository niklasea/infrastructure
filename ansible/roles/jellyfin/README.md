# Jellyfin

## Backup and restore

The backup job in `main.yml` writes `jellyfin.tar.gz` to the configured backup
share. The archive contains the Jellyfin configuration directory.

```sh
docker compose -f /etc/compose/jellyfin/docker-compose.yml stop jellyfin
tar -xzf jellyfin.tar.gz -C /etc/compose/jellyfin/config
docker compose -f /etc/compose/jellyfin/docker-compose.yml start jellyfin
```
