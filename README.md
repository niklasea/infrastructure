# Infrastructure

## Provisioning

Resource provisioning is done via Terraform.

## Server configuration

After provisioning infrastructure, the rest of the configuration is done through Ansible.

### Ansible inventory

Ansible is configured to automatically detect hosts using dynamic inventory. This way, I do not need to product and send host details from Terraform to Ansible.

I am using separate read-only API tokens for the dynamic inventory that are encrypted using `ansible-vault encrypt_string -n <variable_name> '<secret>'` because the dynamic inventory does not make use of the regular vault(s) under `group_vars`.

To see the inventory, install the inventory plugins with `ansible-galaxy install -r requirements.yml` and run `ansible-inventory --graph --ask-vault-pass`.

### Bootstrapping the CI/CD environment

Since I am deploying to my own hardware, I need some way to connect the CI/CD pipeline to my local hypervisor. I do so by setting up VMs on the local network running GitHub Actions and Terraform agents. Since these agent servers otherwise do not need ongoing management, I simply create these through Ansible and run the playbook ad hoc:

`ansible-playbook infrastructure_bootstrap.yml --ask-vault-pass`
