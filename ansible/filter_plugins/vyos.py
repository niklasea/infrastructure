"""Filters for VyOS configuration."""


def vyos_static_routes(vpn_network):
    """Build static routes for a VPN network and the networks behind its peers."""
    gateway = vpn_network["local_address"]
    routes = [{"network": vpn_network["network"], "gateway": gateway}]
    routes.extend(
        {"network": network, "gateway": gateway}
        for network in vpn_network.get("peer_networks", [])
    )
    return routes


class FilterModule:
    """Expose the VyOS filters to Ansible."""

    def filters(self):
        return {"vyos_static_routes": vyos_static_routes}
