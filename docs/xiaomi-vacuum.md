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

The NAT rule matches both the Home Assistant LAN and tunnel subnets against
the vacuum destination, because Docker may masquerade the HA container's
traffic to either address. The forward rules are scoped to the WireGuard
client interface.

## Prerequisites

- Home Assistant 2026.11 or newer (for the built-in Marketplace).
- A DHCP reservation for the vacuum at the Singapore site.
- The Asus SNAT rule installed: [router/asus-merlin](../router/asus-merlin/README.md).

## 1. Router

Follow [router/asus-merlin](../router/asus-merlin/README.md). The short version:

1. Enable JFFS custom scripts on the Asus.
2. Set `VACUUM_IP`, `LAN_IF`, and `WG_IF` in `router/asus-merlin/nat-start`
   (adjust `HA_NET` only if the site subnets differ).
3. Install it as `/jffs/scripts/nat-start` and run it.
4. Make sure the WireGuard client's Allowed IPs include `172.21.0.0/24` and
   `172.21.1.0/24`, and leave the client's own "Enable NAT" off.

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
| Battery   | `sensor.xiaomi_robot_vacuum_x20_battery_level` |
| Map       | `camera.xiaomi_robot_vacuum_x20_map`        |

If the generated IDs differ, either rename them under **Settings → Entities**
or override the values in `ansible/group_vars/all/vars.yml`:

```yaml
# Override the whole mapping; partial overrides are not merged.
home_assistant_vacuum:
  entity: vacuum.your_vacuum
  battery_entity: sensor.your_vacuum_battery_level
  presence_entity: binary_sensor.your_site_occupied
  schedule: "09:30:00"
  min_battery: 30
```

`presence_entity` must track the vacuum's site; leave it empty to clean on
schedule regardless of occupancy. The schedule uses Home Assistant's timezone.

## 4. Room IDs

1. Let the vacuum complete a mapping run.
2. Open **Developer Tools → States**, select the vacuum entity, and read the
   `rooms` attribute. Each room has an `id` and a `name` (or use the map card's
   room configurator).
3. Map room names to room IDs in `home_assistant_vacuum_rooms`:

```yaml
home_assistant_vacuum_rooms:
  kitchen: 3
  living_room: 2
  bedroom: 4
```

Each entry produces a `script.vacuum_clean_<room>` script. Add a button for it
to the dashboard. Leave the mapping empty until the IDs are known.

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
| `vacuum_scheduled_clean`  | Starts at `home_assistant_vacuum.schedule` when the vacuum is docked and the battery is above the threshold; also requires an unoccupied site when `presence_entity` is set |
| `vacuum_presence_clean`   | Created only when `presence_entity` is set; disabled at every Home Assistant start |
| `vacuum_task_completed`   | Mobile and email notification with cleaned area and duration      |
| `vacuum_error`            | Notification with the fault text and code                         |
| `vacuum_warning`          | Notification for dismissible warnings                             |
| `vacuum_consumable`       | At most one maintenance notification per week across all consumables |
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
# On the Asus
iptables -t nat -L POSTROUTING -vn | grep ha-vacuum-snat
cat /proc/net/nf_conntrack | grep 54321
```

The conntrack entry should show the source translated to the router's LAN
address. The integration's local connection is the definitive test; TCP may be
closed even when miIO over UDP works.

In Home Assistant:

1. Run `script.vacuum_start` and confirm the vacuum leaves the dock.
2. Confirm the map camera renders.
3. Run a room script and confirm it cleans the right room.
4. Confirm the completion notification arrives.

## Troubleshooting

| Symptom                              | Likely cause                                                     |
| ------------------------------------ | ---------------------------------------------------------------- |
| Integration setup cannot reach device | SNAT missing, WireGuard client down, or Allowed IPs missing `172.21.0.0/24` or `172.21.1.0/24` |
| Commands work but map is empty        | The map is cloud-fetched; check internet access and re-authenticate |
| Room script cleans the wrong room     | Room IDs changed after remapping; update `home_assistant_vacuum_rooms` |
| Scheduled run never starts            | `presence_entity`, `battery_entity`, or `min_battery` is wrong |
| `vacuum_offline` fires repeatedly     | Tunnel or Singapore site down; check the Asus and its WAN          |
| Notifications missing                 | `home_assistant_notify.email` / `.mobile` services changed         |

## Rollback

1. Remove the `packages/vacuum.yaml.j2` entry from
   `home_assistant_config_files` and redeploy, then delete
   `packages/vacuum.yaml` from the config directory and restart Home Assistant.
2. Remove the integration under **Settings → Devices & services**.
3. Run `/jffs/scripts/nat-start remove` on the Asus and delete the script.
