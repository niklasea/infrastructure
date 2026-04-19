resource "proxmox_virtual_environment_file" "cloud_config" {
  for_each     = var.proxmox_vms
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.proxmox_node_name

  source_raw {
    data = templatefile("${path.module}/cloud-init.tftpl", {
      hostname       = each.key
      ssh_keys       = values(var.ssh_public_keys)
      extra_packages = ["qemu-guest-agent"]
      run_commands   = ["systemctl enable qemu-guest-agent", "systemctl start qemu-guest-agent"]
    })

    file_name = "cloud-init-${each.key}.yaml"
  }
}

resource "proxmox_download_file" "cloud_image" {
  content_type        = "import"
  datastore_id        = "local"
  node_name           = var.proxmox_node_name
  url                 = var.pve_image
  overwrite_unmanaged = true
}

resource "proxmox_virtual_environment_vm" "virtual_machines" {
  for_each = var.proxmox_vms
  name     = each.key
  tags     = each.value.tags

  node_name = var.proxmox_node_name
  on_boot   = true

  cpu {
    cores = each.value.vcpu
    type  = "host"
  }
  memory {
    dedicated = each.value.memory_mb
  }
  disk {
    datastore_id = "local-lvm"
    import_from  = proxmox_download_file.cloud_image.id
    interface    = "virtio0"
    size         = each.value.storage_gb
    iothread     = true
    discard      = "on"
  }
  network_device {
    bridge  = "vmbr0"
    model   = "virtio"
    mtu     = 1 # Use bridge MTU
    vlan_id = each.value.vlan_id
  }

  agent {
    enabled = true
  }
  initialization {
    dns {
      servers = ["1.1.1.1", "1.0.0.1", "8.8.8.8", "8.8.4.4"]
    }
    ip_config {
      ipv4 {
        address = "dhcp"
      }
      ipv6 {
        address = "dhcp"
      }
    }
    datastore_id      = "local-lvm"
    user_data_file_id = proxmox_virtual_environment_file.cloud_config[each.key].id
  }
}

output "proxmox_ips" {
  description = "Map of Proxmox VM names to their IP addresses"
  value = {
    # Since Proxmox VMs can have multiple interfaces/IPs,
    # we grab the first IP of the first interface.
    for name, vm in proxmox_virtual_environment_vm.virtual_machines :
    name => try(flatten(vm.ipv4_addresses)[0], "pending")
  }
}
