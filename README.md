# gaire-lab-automation
gaire-lab-automation

Run Terraform,
Update Public IP in 2 places inside hosts file in ansible>inventory>hosts.yml
ansible azure_lab_vm -m ping -e "ansible_user=lab.admin"
ansible-playbook playbooks/base-setup.yml -e "ansible_user=lab.admin"
ansible-playbook playbooks/deploy-k3s.yml
ansible-playbook playbooks/deploy-stack.yml


### 🚀 Infrastructure Reconstruction & Baseline Realignment
* **Tear-Down & Spin-Up:** Executed `terraform destroy` followed by `terraform apply` to resolve state drift and rebuild the lab environment. Update Public IP in 2 places inside hosts file in ansible>inventory>hosts.yml
* **IP Anchoring:** Decoupled and fixed internal private IPs (`10.0.1.5` / `10.0.1.6`) on the K3s cluster nodes via Terraform configuration to guarantee static proxy alignment. Already defined on Terraform now on main.tf
* **Bootstrap Variable Overrides:** Utilized high-priority Ansible Extra Variables (`-e "ansible_user=lab.admin"`) to bypass default inventory configurations and establish the baseline OS environment on the fresh gateway. | ansible-playbook playbooks/base-setup.yml -e "ansible_user=lab.admin"
* **Core Hardening & User Provisioning:** Orchestrated package upgrades, UFW firewall active matrices, and initialized the permanent `ops` user automation profile. | ansible-playbook playbooks/deploy-k3s.yml
* **SSH Multi-Hop Tunneling:** Verified internal control plane orchestration by executing `deploy-k3s.yml` directly across the secure gateway SSH proxy tunnel.
* **Edge Application Deployment:** Provisioned a 4GB system swap allocation and built a custom DuckDNS-enabled Caddy container on `azure_lab_vm` to reverse-proxy core services (**n8n, Portainer, Ollama, Open WebUI**). | ansible-playbook playbooks/deploy-stack.yml




Disaster Recovery Checklist for a New Laptop
Looking closely at your attached folder tree, your .gitignore is successfully keeping sensitive states and configurations local. If your current machine completely dies and you pull this repository down onto a brand-new laptop, the repository will intentionally be missing your structural states and keys.

Here is the exact checklist of the files you will need to manually recreate or copy from your secure backups to get the lab automation engine running again:

1. In the terraform/ Folder
terraform.tfvars

What it holds: Your live Azure subscription IDs, cloud tenant credentials, and the administrative root user passwords used to provision the baseline VMs.

terraform.tfstate & terraform.tfstate.backup

What it holds: The cryptographic map tracking exactly which real Azure hardware resources belong to your configuration files.

Note: If you don't have this file on a new laptop, running terraform apply will think nothing exists and try to build duplicate VMs, causing a crash. You either need to back this state file up securely or run terraform import for your resources.

2. In the ansible/ Folder
ansible/playbooks/vars/secrets.yml

What it holds: Your unencrypted variables like vault_duckdns_token and plaintext setup targets like your ollama_admin_password.

ansible/playbooks/.kube/config

What it holds: Your administrative authentication token context needed to issue remote commands down to your K3s cluster nodes using your local control utility engines.

3. In Your Local Machine User Profile (~/.ssh/)
~/.ssh/azure-lab-private-key

What it holds: The private OpenSSH key pair file required to pass through the front gateway and decrypt the target authentication chains inside your automated script manifests. Without this local file, every single connection handshake will fail.