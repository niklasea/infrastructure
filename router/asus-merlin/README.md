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

Find the LAN interface that routes to the vacuum:

```sh
ip route get 192.168.50.50
# ... dev br0 ...
```

Edit the two variables at the top of `nat-start`:

| Variable     | Value                                                     |
| ------------ | --------------------------------------------------------- |
| `VACUUM_IP`  | The vacuum's DHCP reservation                             |
| `LAN_IF`     | `br0` for the main LAN, or the `dev` printed above        |

The rule matches the **destination** rather than Home Assistant's source
address. Docker may masquerade the HA container's traffic to the WireGuard
interface address (`172.21.0.1`) instead of the LAN address, so a source match
would miss it. Matching the vacuum IP still keeps the rule scoped to the
vacuum.

Copy it to the router and run it:

```sh
scp nat-start admin@192.168.50.1:/jffs/scripts/nat-start
ssh admin@192.168.50.1
chmod 755 /jffs/scripts/nat-start
/jffs/scripts/nat-start
```

`nat-start` runs at boot and after each firewall reload, so the rule is
persistent. Running it twice is safe: existing rules are detected with
`iptables -C`.

## Verify

On the router:

```sh
iptables -t nat -L POSTROUTING -vn | grep 192.168.50.50
iptables -L FORWARD -vn | grep 54321
cat /proc/net/nf_conntrack | grep 54321
```

From the Home Assistant container:

```sh
nc -vz 192.168.50.50 54321
```

The conntrack entry should show the source translated to the router's LAN
address. That is the signal the vacuum will accept the miIO session.

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

| Symptom                                  | Check                                                       |
| ---------------------------------------- | ----------------------------------------------------------- |
| No rule in `POSTROUTING`                 | Script not executable, JFFS scripts disabled, or not run    |
| Rule present, no conntrack entry         | WireGuard client down, or Allowed IPs missing `172.21.1.0/24` |
| Conntrack entry, `nc` still times out    | Router FORWARD policy, or the server-side route             |
| Works, then breaks after reboot          | `nat-start` not in `/jffs/scripts` or not executable         |

Do not enable global NAT on the client as a shortcut. It makes the vacuum work
but changes the source address for all tunnel traffic and can break the
two-way site-to-site access.
