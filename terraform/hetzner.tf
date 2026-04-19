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

# A single resource block provisions every server in the map
resource "hcloud_server" "nodes" {
  for_each = var.hcloud_servers

  image       = var.hcloud_image
  name        = each.key
  server_type = each.value.server_type
  location    = each.value.location
  labels      = each.value.labels

  firewall_ids = [hcloud_firewall.ssh-only-firewall.id]
  user_data = templatefile("${path.module}/cloud-init.yaml", {
    ssh_keys = var.ssh_public_keys
  })
}

output "hetzner_ips" {
  description = "Map of Hetzner server names to their public IPv4 addresses"
  value = {
    for name, server in hcloud_server.nodes : name => server.ipv4_address
  }
}
