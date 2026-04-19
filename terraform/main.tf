terraform {
  required_version = "~> 1.14"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.102.0"
    }
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.60.1"
    }
  }

  cloud {
    organization = "niklasea-terraform-org"
    workspaces {
      name = "infrastructure_terraform"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_url
  api_token = var.proxmox_api_token
  insecure  = true
}

provider "hcloud" {
  token = var.hcloud_token
}
