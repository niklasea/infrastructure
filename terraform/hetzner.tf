resource "hcloud_firewall" "ssh-only-firewall" {
  name = "ssh-only"
  rule {
    description = "Allow ICMP"
    direction   = "in"
    protocol    = "icmp"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }
  rule {
    description = "Allow SSH"
    direction   = "in"
    protocol    = "tcp"
    port        = "22"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_firewall" "webserver-firewall" {
  name = "webserver"
  rule {
    description = "Allow HTTP"
    direction   = "in"
    protocol    = "tcp"
    port        = "80"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }
  rule {
    description = "Allow HTTPS"
    direction   = "in"
    protocol    = "tcp"
    port        = "443"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_firewall" "netbird-stun-firewall" {
  name = "netbird"
  rule {
    description = "Allow STUN"
    direction   = "in"
    protocol    = "udp"
    port        = "3478"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }
}

# The Singapore WAN address is dynamic, so the source cannot be narrowed.
# The tunnel is IPv4 only, so the router must use the server's IPv4 endpoint.
resource "hcloud_firewall" "wireguard-sin-firewall" {
  name = "wireguard-sin"
  rule {
    description = "Allow the Singapore router DNS tunnel"
    direction   = "in"
    protocol    = "udp"
    port        = "51821"
    source_ips  = ["0.0.0.0/0"]
  }
}

# A single resource block provisions every server in the map
resource "hcloud_server" "nodes" {
  for_each = var.hcloud_servers

  image       = var.hcloud_image
  name        = each.key
  server_type = each.value.server_type
  location    = each.value.location
  labels      = each.value.labels

  firewall_ids = concat(
    [
      hcloud_firewall.ssh-only-firewall.id,
      hcloud_firewall.webserver-firewall.id,
      hcloud_firewall.netbird-stun-firewall.id
    ],
    # The Singapore router terminates its DNS tunnel on this host.
    each.key == "kubernetes-sin" ? [hcloud_firewall.wireguard-sin-firewall.id] : []
  )
  user_data = templatefile("${path.module}/cloud-init.tftpl",
    {
      hostname       = each.key
      fqdn           = ""
      ssh_keys       = values(var.ssh_public_keys)
      extra_packages = []
      run_commands   = []
  })

  lifecycle {
    ignore_changes = [ user_data ]
    prevent_destroy = true
  }
}

output "hetzner_ips" {
  description = "Map of Hetzner server names to their public IPv4 addresses"
  value = {
    for name, server in hcloud_server.nodes : name => server.ipv4_address
  }
}
