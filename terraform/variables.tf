variable "hcloud_token" {
  type      = string
  sensitive = true
}
variable "proxmox_api_token" {
  type      = string
  sensitive = true
}
variable "proxmox_url" {
  type = string
}
variable "proxmox_node_name" {
  type = string
}

# Global OS Config
variable "hcloud_image" {
  type    = string
  default = "debian-13"
}
variable "pve_image" {
  type    = string
  default = "https://cdimage.debian.org/cdimage/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
}
variable "ssh_public_keys" {
  type = map(string)
  default = {
    "deployment" = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID8r7hgtHyKnvstg62wRJbyML+A4twqGFpH+O+RUixgV deployment"
  }
}

variable "hcloud_servers" {
  type = map(object({
    location    = string
    server_type = string
    labels      = map(string)
  }))
}

variable "proxmox_vms" {
  type = map(object({
    vcpu         = number
    memory_mb    = number
    storage_gb   = number
    vlan_id      = number
    tags         = list(string)
  }))
}
