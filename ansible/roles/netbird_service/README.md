# Netbird service

## Backup and restore

The backup job in `overlay_networking.yml` writes `netbird-data.tar.gz` to the
configured backup share. The archive contains the contents of
`/var/lib/netbird` from the `netbird-server` container.

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
