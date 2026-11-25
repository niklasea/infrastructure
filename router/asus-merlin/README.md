# Asuswrt-Merlin: SNAT for the Xiaomi vacuum

The Asus at the Singapore site is the WireGuard **client**; the WireGuard
server runs on `internal-docker` at the Home Assistant site. The server peer
`AsusSingapore` already allows the Singapore LAN:

```yaml
# ansible/host_vars/internal-docker.yml
AsusSingapore:
  AllowedIPs:
    - 172.21.0.7/32
    - 192.168.50.0/24
```

That is enough for routing, but Xiaomi vacuums drop miIO requests whose source
address is not in their own subnet. `nat-start` masquerades Home Assistant's
traffic to this router's LAN address before it reaches the vacuum, which is the
workaround documented by python-miio.

## Prerequisites

1. A DHCP reservation for the vacuum at the Singapore site.
2. **Administration → System → Enable JFFS custom scripts and configs = Yes**,
   then reboot the router.
3. SSH access to the router.

## Install

Find the LAN interface that routes to the vacuum and the WireGuard client
interface:

```sh
ip route get 192.168.50.50
# ... dev br0 ...
wg show interfaces
# wg11 ...
```

Edit the variables at the top of `nat-start`:

| Variable    | Value                                               |
| ----------- | --------------------------------------------------- |
| `VACUUM_IP` | The vacuum's DHCP reservation                       |
| `LAN_IF`    | `br0` for the main LAN, or the `dev` printed above  |
| `WG_IF`     | The WireGuard client interface printed above        |
| `HA_NET`    | Home Assistant and tunnel subnets (`172.21.0.0/23`) |

The NAT rule matches both possible source subnets and the vacuum destination.
Docker may masquerade the HA container's traffic to the tunnel address instead
of the LAN address, so a single source match would miss one of them. The
forward rules are additionally scoped to the WireGuard client interface.

Copy it to the router and run it:

```sh
scp nat-start admin@192.168.50.1:/jffs/scripts/nat-start
ssh admin@192.168.50.1
chmod 755 /jffs/scripts/nat-start
/jffs/scripts/nat-start
```

`nat-start` runs at boot and after each firewall reload, so the rules are
persistent. Running it twice is safe: existing rules are detected with
`iptables -C`. Run `nat-start remove` before changing `VACUUM_IP`, `WG_IF`, or
`HA_NET` so rules for the old values are deleted.

## Verify

On the router:

```sh
iptables -t nat -L POSTROUTING -vn | grep ha-vacuum-snat
iptables -L FORWARD -vn | grep ha-vacuum-snat
cat /proc/net/nf_conntrack | grep 54321
```

The conntrack entry should show the source translated to the router's LAN
address. The integration's local connection is the definitive test; TCP 54321
may be closed even when miIO over UDP works.

## WireGuard client settings

In the Merlin WireGuard client profile:

- **Allowed IPs** must include `172.21.1.0/24` so replies to Home Assistant
  are routed back through the tunnel. Include `172.21.0.0/24` for the tunnel
  subnet as well.
- Leave **Enable NAT** off. The scoped `nat-start` rule is deliberately limited
  to the vacuum; a blanket masquerade would hide source addresses for every
  other device on the tunnel.

## Rollback

```sh
/jffs/scripts/nat-start remove
rm /jffs/scripts/nat-start
```

## Troubleshooting

| Symptom                                     | Check                                                                            |
| ------------------------------------------- | -------------------------------------------------------------------------------- |
| No rule tagged `ha-vacuum-snat`             | Script not executable, JFFS scripts disabled, or not run                         |
| Rule present, no conntrack entry            | WireGuard client down, or Allowed IPs missing `172.21.0.0/24` or `172.21.1.0/24` |
| Conntrack entry, integration cannot connect | Router FORWARD policy, or the server-side route                                  |
| Works, then breaks after reboot             | `nat-start` not in `/jffs/scripts` or not executable                             |

Do not enable global NAT on the client as a shortcut. It makes the vacuum work
but changes the source address for all tunnel traffic and can break the
two-way site-to-site access.
