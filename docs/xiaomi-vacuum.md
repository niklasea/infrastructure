# Xiaomi Robot Vacuum (X20+)

The vacuum lives at the Singapore site. Home Assistant runs at the main site
and reaches the vacuum over the site-to-site WireGuard tunnel. Because Xiaomi
vacuums only answer miIO requests whose source address is in their own subnet,
the Asus router masquerades Home Assistant's traffic before it reaches the
vacuum.

```text
Home Assistant (internal-docker)
  172.21.1.30  -- WireGuard server (internal-docker, wg0) --
      == tunnel ==
  Asus Merlin (client) -- SNAT -- Xiaomi X20+ (192.168.50.x)
```

Control and state are local over the tunnel. The Xiaomi cloud is still used to
fetch the map and to sign in.

The router rule matches the vacuum's destination address, not Home Assistant's
source address: Docker may masquerade the HA container's traffic to the
WireGuard interface address (`172.21.0.1`) rather than the LAN address.

## Prerequisites

- Home Assistant 2026.11 or newer (for the built-in Marketplace).
- A DHCP reservation for the vacuum at the Singapore site.
- The Asus SNAT rule installed: [router/asus-merlin](../router/asus-merlin/README.md).

## 1. Router

Follow [router/asus-merlin](../router/asus-merlin/README.md). The short version:

1. Enable JFFS custom scripts on the Asus.
2. Set `VACUUM_IP` and `LAN_IF` in `router/asus-merlin/nat-start`.
3. Install it as `/jffs/scripts/nat-start` and run it.
4. Make sure the WireGuard client's Allowed IPs include `172.21.1.0/24`, and
   leave the client's own "Enable NAT" off.

## 2. Install the integration

The integration is UI-managed, like other Marketplace content, so it is not
part of the Ansible copy step.

1. **Settings → Marketplace → Add from link**, enter
   `Tasshack/dreame-vacuum`, type **Integration**, add it, and install
   **Dreame Vacuum**.
2. Restart Home Assistant.
3. **Settings → Devices & services → Add integration → Dreame Vacuum**.
4. Choose **Xiaomi Home account**, the region the vacuum is registered in, and
   the account credentials used in the Mi Home app.
5. Complete the captcha or 2FA prompt if asked.
6. **Uncheck Prefer Cloud** so the integration fetches the token and connects
   locally over the tunnel.
7. Select the X20+ (`xiaomi.vacuum.c102gl`).

If setup reports "cannot reach device", fix the router rule or the Allowed IPs
before falling back to cloud mode.

## 3. Entity IDs

The package defaults to:

| Entity    | ID                                          |
| --------- | ------------------------------------------- |
| Vacuum    | `vacuum.xiaomi_robot_vacuum_x20`            |
| Map       | `camera.xiaomi_robot_vacuum_x20_map`        |

If the generated IDs differ, either rename them under **Settings → Entities**
or override the values in `ansible/group_vars/all/vars.yml`:

```yaml
home_assistant_vacuum:
  entity: vacuum.your_vacuum
  map_entity: camera.your_vacuum_map
  schedule: "09:30:00"
  min_battery: 30
```

## 4. Room segments

1. Let the vacuum complete a mapping run.
2. Open **Developer Tools → States**, select the vacuum entity, and read the
   `segments` attribute (or use the map card's room configurator).
3. Map room names to segment IDs in `home_assistant_vacuum_rooms`:

```yaml
home_assistant_vacuum_rooms:
  kitchen: 3
  living_room: 2
  bedroom: 4
```

Each entry produces a `script.vacuum_clean_<room>` script. Add a button for it
to the dashboard. Leave the mapping empty until the segment IDs are known.

## 5. Deploy the Home Assistant package

The package is rendered by the `home_assistant` role from
`ansible/roles/home_assistant/templates/packages/vacuum.yaml.j2`.

```sh
cd ansible
ansible-playbook main.yml --ask-vault-pass --limit internal-docker
```

The role validates the configuration and restarts Home Assistant through the
`restart_home_assistant` handler. Merging to `main` also triggers the normal
CI/CD deploy.

### What the package does

| Automation                | Behaviour                                                        |
| ------------------------- | ---------------------------------------------------------------- |
| `vacuum_scheduled_clean`  | Starts a whole-home clean at `home_assistant_vacuum.schedule` when nobody is home, the vacuum is docked, and the battery is above the threshold |
| `vacuum_presence_clean`   | Disabled by default; cleans when the last person leaves           |
| `vacuum_task_completed`   | Mobile and email notification with cleaned area and duration      |
| `vacuum_error`            | Notification with the fault text and code                         |
| `vacuum_warning`          | Notification for dismissible warnings                             |
| `vacuum_consumable`       | Notification when a brush, filter, sensor, or mop pad is low      |
| `vacuum_offline`          | Notification if the vacuum is unavailable for 15 minutes          |

The completion, error, warning, and consumable automations use the
integration's events (`dreame_vacuum_task_status`, `dreame_vacuum_error`,
`dreame_vacuum_warning`, `dreame_vacuum_consumable`), so they do not depend on
generated sensor entity IDs.

## 6. Dashboard

Add the free Xiaomi Vacuum Map Card, then use its configurator to generate the
room list:

```yaml
type: custom:xiaomi-vacuum-map-card
entity: vacuum.xiaomi_robot_vacuum_x20
map_source:
  camera: camera.xiaomi_robot_vacuum_x20_map
calibration_source:
  camera: true
vacuum_platform: Tasshack/dreame-vacuum
```

The integration also bundles the Dreame Vacuum Card
(`type: custom:dreame-vacuum-card`), but it requires a paid per-device licence.

Add buttons for `script.vacuum_start` and any generated
`script.vacuum_clean_<room>` scripts.

## 7. Verify

```sh
# From the Home Assistant container
nc -vz <VACUUM_IP> 54321

# On the Asus
iptables -t nat -L POSTROUTING -vn | grep <VACUUM_IP>
cat /proc/net/nf_conntrack | grep 54321
```

In Home Assistant:

1. Run `script.vacuum_start` and confirm the vacuum leaves the dock.
2. Confirm the map camera renders.
3. Run a room script and confirm it cleans the right room.
4. Confirm the completion notification arrives.

## Troubleshooting

| Symptom                              | Likely cause                                                     |
| ------------------------------------ | ---------------------------------------------------------------- |
| Integration setup cannot reach device | SNAT missing, WireGuard client down, or Allowed IPs missing `172.21.1.0/24` |
| Commands work but map is empty        | The map is cloud-fetched; check internet access and re-authenticate |
| Room script cleans the wrong room     | Segment IDs changed after remapping; update `home_assistant_vacuum_rooms` |
| `vacuum_offline` fires repeatedly     | Tunnel or Singapore site down; check the Asus and its WAN          |
| Notifications missing                 | `home_assistant_notify.email` / `.mobile` services changed         |

## Rollback

1. Remove the `packages/vacuum.yaml.j2` entry from
   `home_assistant_config_files` and redeploy, then delete
   `packages/vacuum.yaml` from the config directory.
2. Remove the integration under **Settings → Devices & services**.
3. Run `/jffs/scripts/nat-start remove` on the Asus and delete the script.
