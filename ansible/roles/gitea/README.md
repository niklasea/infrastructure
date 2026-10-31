# Gitea

## Backup and restore

The backup job in `main.yml` streams `gitea dump` to `gitea-dump.zip` on the
configured backup share. The archive contains the database, repositories,
configuration, and attachments.

```sh
docker compose -f /etc/compose/gitea/docker-compose.yml stop gitea
unzip gitea-dump.zip -d gitea-restore
```

Restore the database, `repos/`, and `data/` contents from the extracted
archive to the Gitea data directory, then start the container:

```sh
docker compose -f /etc/compose/gitea/docker-compose.yml start gitea
```
