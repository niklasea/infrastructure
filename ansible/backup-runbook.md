# Backup runbook

## Architecture

```text
internal-docker ─┐
public-docker  ─┼── HTTPS ──→ backup01 (Debian VM)
dns01/dns02    ─┘                │  rest-server --append-only
netbird        ─┘                │  restic prune / check / monitor
                                  ▼
                             harkonnen (TrueNAS SCALE)
                               dataset backup/restic
                               ├── periodic ZFS snapshots
                               └── versioned/immutable offsite replication
```

- `backup01` runs `rest-server` and owns the repository credentials used for
  pruning and verification. It stores no backup data locally.
- TrueNAS exports one dataset over NFS to `backup01` only. Clients never see NFS
  or repository credentials with delete access.
- TrueNAS snapshots and the existing offsite replication are the recovery path
  if `backup01` is lost or compromised.
- Caddy on `backup01` terminates TLS for `backup.internal.<domain>` and proxies
  to `rest-server` on loopback.

## TrueNAS preparation

1. Create a dataset named `backup/restic` (separate from `Immich` and `Media`).
2. Create a `restic` user and group with UID/GID `3000`. Override
   `restic_server_uid` and `restic_server_gid` if those IDs are already used.
3. Export the dataset over NFS to `backup01` only. Map all access to the
   `restic` user/group, and export it read-write and synchronous.
4. Add a periodic snapshot task for the dataset. A reasonable starting point is
   hourly with 7 days, daily with 30 days, and weekly with 6 months.
5. Add the dataset to the existing versioned/immutable offsite replication.
6. Export the TrueNAS configuration (`System Settings -> General -> Save
   Config`) and store it offsite.
7. Set `restic_server_nfs_source` in `ansible/host_vars/backup01.yml` to the
   actual NFS path, for example `harkonnen.internal.example.com:/mnt/tank/backup/restic`.

Snapshot the repository before or after pruning so a bad prune can be rolled
back. Restic tolerates interrupted writes, but run the first `restic check`
after the initial backup and prune cycle.

## Provision backup01

`backup01` is a small Debian VM: 2 vCPU, 2 GB RAM, 16 GB disk, VLAN 10. It is
expected in the `role_backup` inventory group through the Proxmox tag `backup`.

If the VM is provisioned through Terraform, add it to the existing
`proxmox_vms` map. The MAC address and IP must match the `backup01` entry in
`ansible/group_vars/all/vars.yml`:

```hcl
backup01 = {
  vcpu             = 2
  memory_mb        = 2048
  storage_gb       = 16
  vlan_id          = 10
  tags             = ["backup"]
  hardware_address = "BC:24:11:7B:AC:01"
}
```

The `backup` alias in `alternate_hostnames` makes VyOS resolve
`backup.internal.<domain>` for the Caddy certificate and client repository URL.
The public VLAN firewall rule allows `public-docker` to reach `backup01:443`.

## Required vault values

Add these to `ansible/group_vars/all/vault` with `ansible-vault edit`:

```yaml
vault_restic_server_users:
  dns01: "<random alphanumeric password>"
  dns02: "<random alphanumeric password>"
  internal-docker: "<random alphanumeric password>"
  netbird: "<random alphanumeric password>"
  public-docker: "<random alphanumeric password>"

vault_restic_repo_passwords:
  dns01: "<random alphanumeric password>"
  dns02: "<random alphanumeric password>"
  internal-docker: "<random alphanumeric password>"
  netbird: "<random alphanumeric password>"
  public-docker: "<random alphanumeric password>"
```

Generate values with `openssl rand -hex 32`. Avoid characters that need URL
escaping because the rest-server password is embedded in the repository URL.

Optionally add dead-man's-switch URLs. Keys are the host name for client
healthchecks and `backup01` for the server monitor:

```yaml
vault_restic_healthcheck_urls:
  backup01: "https://hc-ping.com/<uuid>"
  internal-docker: "https://hc-ping.com/<uuid>"
  public-docker: "https://hc-ping.com/<uuid>"
  netbird: "https://hc-ping.com/<uuid>"
  dns01: "https://hc-ping.com/<uuid>"
  dns02: "https://hc-ping.com/<uuid>"
```

Escrow both repository password sets outside the infrastructure. Losing them
makes the backups unrecoverable.

## Deploy

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook main.yml --ask-vault-pass
```

The playbook:

- mounts the TrueNAS dataset and starts `rest-server` on `backup01`;
- initializes one repository per host;
- installs the restic client, per-job scripts, and daily systemd timers;
- removes the old backup cron entries by name.

Run one job manually before relying on the timers:

```bash
systemctl start restic-backup-compose.service
journalctl -u restic-backup-compose.service -n 50 --no-pager
```

On `backup01`:

```bash
sudo -u restic restic -r /srv/restic/internal-docker \
  --password-file /etc/restic/internal-docker.pass snapshots
systemctl list-timers 'restic*'
```

Verify append-only protection from a client:

```bash
restic -r 'rest:https://<host>:<rest-server-password>@backup.internal.<domain>/<host>/' \
  --password-file /etc/restic/password forget --prune --keep-last 1
```

This must fail with an authorization error. If it succeeds, `--append-only` is
not active.

## Jobs

All times are local. Each client timer gets a randomized delay of up to 30
minutes.

| Host | Job | Time | Contents |
| --- | --- | --- | --- |
| internal-docker | compose | 02:00 | `/etc/compose` (including WireGuard config), excluding live app data |
| internal-docker | gitea | 02:15 | `gitea dump` archive |
| internal-docker | vaultwarden | 02:30 | SQLite snapshot plus attachments, sends and keys |
| internal-docker | home-assistant | 02:45 | SQLite snapshot plus config, excluding logs and HA backups |
| internal-docker | jellyfin | 03:00 | config, metadata and consistent SQLite snapshots, excluding cache and transcodes |
| internal-docker | immich | 03:15 | `pg_dump`; the photo library stays on TrueNAS |
| public-docker | linuxgsm | 03:30 | game saves, configs and CS:GO maps/addons |
| netbird | netbird | 03:45 | NetBird data volume and compose config |
| dns01/dns02 | blocky | 04:00 | Blocky configuration |
| backup01 | prune | Sunday 05:30 | retention and prune |
| backup01 | check | Sunday 06:30 | repository metadata check |
| backup01 | check-data | 1st of month 07:00 | 5% data verification |
| backup01 | monitor | daily 08:00 | snapshot age check |

Retention defaults to 14 daily, 8 weekly, 24 monthly and 3 yearly snapshots per
host and tag. Adjust `restic_server_retention` in
`ansible/roles/restic_server/defaults/main.yml`.

The monitor checks the newest snapshot for every tag in every repository. If a
job is removed, forget its old tag or the monitor will keep reporting it as
stale until retention removes it.

Staging lives on each client's root disk. Make sure there is room for the
largest database dump, especially the Immich and Gitea dumps.

## Restore

List snapshots:

```bash
restic -r /srv/restic/<host> --password-file /etc/restic/<host>.pass snapshots
```

Restore a path without overwriting the live system:

```bash
restic -r /srv/restic/<host> --password-file /etc/restic/<host>.pass \
  restore latest --target /tmp/restore --include /etc/compose/gitea
```

Restore commands run either on `backup01` with the repository path, or from a
client with its repository URL. Prefer restoring to a staging directory and
copying into place.

### Application notes

- **Gitea**: restore the `gitea-dump.tar.gz` archive. It contains the database,
  repositories and configuration. Verify LFS coverage before relying on it for
  LFS-heavy repositories.
- **Vaultwarden**: restore the data directory and the SQLite snapshot from
  `db.sqlite3` in the staging path. Stop the container before replacing the live
  database.
- **Home Assistant**: restore the config directory and the
  `home-assistant_v2.db` snapshot from staging. Exclude the live database and
  WAL files when copying back.
- **Immich**: restore `immich-db.sql` into PostgreSQL before starting the
  application. The upload library is on TrueNAS and is covered by the TrueNAS
  snapshots and offsite replication, not by restic.
- **Jellyfin**: restore the config directory and the consistent SQLite snapshots
  from staging. Media is not backed up.
- **NetBird**: restore the copied `/var/lib/netbird` data into the
  `netbird_data` volume and restore the compose configuration.
- **LinuxGSM**: restore the staged config and save directories into each
  instance's data directory. Saves are copied while the game server is running;
  stop the container first if you need strict on-disk consistency.
- **NetBird**: the server is stopped briefly while its data directory is copied,
  then started again.

### Full host recovery

1. Provision the VM with Terraform or the Proxmox Ansible role.
2. Run the normal Ansible playbook to recreate Docker, application roles and
   mounts.
3. Restore `/etc/compose` and the application data from restic.
4. Start the compose projects and verify the applications.

### TrueNAS recovery

- Clone the dataset snapshot and inspect the repository before rolling back the
  live dataset.
- If the NAS itself is lost, restore the `backup/restic` dataset from the
  versioned offsite copy, then remount it on a rebuilt `backup01`.
- Restore the TrueNAS configuration export after rebuilding the NAS.

## Monitoring

- Client jobs ping their optional Healthchecks URL on success and `/fail` on
  error.
- `restic-monitor.service` checks that every repository has a snapshot newer
  than 26 hours and pings the `backup01` Healthchecks URL.
- `restic-check.timer` and `restic-check-data.timer` surface repository
  corruption.
- TrueNAS should alert on snapshot and replication failures independently.

Useful commands:

```bash
systemctl status rest-server
journalctl -u rest-server -n 50 --no-pager
systemctl list-timers 'restic*'
journalctl -u restic-prune.service -u restic-check.service -u restic-monitor.service
```

## Migration from the old cron backups

The previous `tar.gz` cron jobs wrote directly to SMB shares. The playbook
removes the cron entries by name; the old files and mounts are left in place so
nothing is deleted automatically.

Verify there are no legacy entries left, including any orphaned lines from the
old NetBird job:

```bash
crontab -l | grep -F '#Ansible: Back up'
```

After the first restic restore drill succeeds:

1. Remove the old `/mnt/backup/*` mounts from `/etc/fstab` and unmount them.
2. Delete the legacy `ServerBackup` content on `harkonnen`.
3. Keep the old tarballs for one retention cycle if you want a second copy
   during the transition.
4. Remove the unused `vault_smb_server_backup_credentials` from the vault.

The Immich role also removes the legacy `backup.sh` from the compose directory.

## Security notes

- `backup01` is a trust anchor: keep it minimal, patched, and reachable only
  from the internal network and the public Docker host.
- Repository passwords live on the clients so they can write. Append-only
  prevents deletion, not reads of that host's own snapshots.
- The NFS export is restricted to `backup01`; clients never receive NFS
  credentials.
- TrueNAS snapshots are not deletable by the NFS user. The offsite copy is
  versioned, so a bad prune or NAS compromise can be rolled back.
- Backups contain application secrets (`.env`, WireGuard keys, Vaultwarden data).
  The repository is encrypted client-side; treat the repository passwords as
  highly sensitive.

## Out of scope

- Whole-VM backups (Proxmox Backup Server remains a good second layer).
- The Immich photo library and Jellyfin media, which are covered by TrueNAS
  snapshots and offsite replication instead.
- Hetzner DNS servers, which are excluded from the client play.
- VyOS configuration, which can be added as a separate job if desired.
