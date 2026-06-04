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









# gaire-lab-automation
gaire-lab-automation

## 🛠️ Step-by-Step Rebuild & Execution Order

If you are setting up from scratch (or after a `terraform destroy`), follow this exact sequence:

### Phase 1: Infrastructure Provisioning (Terraform)
1. Navigate to your Terraform directory and deploy the core VMs and networks:
   ```bash
   cd terraform/
   terraform init
   terraform apply
2. IP Update: Copy the new Public IP from the Terraform output and update it in two places inside your Ansible inventory file: ansible/inventory/hosts.yml.

3. cd ../ansible/

# 1. Verify connection to the new VM
ansible azure_lab_vm -m ping -e "ansible_user=lab.admin"

# 2. Hardened OS baseline & permanent 'ops' user initialization
ansible-playbook playbooks/base-setup.yml -e "ansible_user=lab.admin"

# 3. Provision K3s Cluster control plane and node infrastructure
ansible-playbook playbooks/deploy-k3s.yml

# 4. Deploy gateway apps (Caddy Proxy with DuckDNS, n8n, Portainer, Ollama, Open WebUI)
ansible-playbook playbooks/deploy-stack.yml

4. cd k3s-manifests/

# 1. Deploy the 'whoami' network test applications
kubectl apply -f whoami-service.yaml
kubectl apply -f whoami-deployment.yaml
kubectl apply -f whoami-ingress.yaml

# 2. Deploy the Persistent Volume Claim for database storage
kubectl apply -f memos-pvc.yaml

# 3. Deploy the 'memos' application (automatically consumes and binds to the PVC)
kubectl apply -f memos-deployment.yaml
kubectl apply -f memos-ingress.yaml








🚀 Infrastructure Reconstruction & Baseline Realignment Notes
Tear-Down & Spin-Up: Executed terraform destroy followed by terraform apply to resolve state drift and rebuild the lab environment.

IP Anchoring: Decoupled and fixed internal private IPs (10.0.1.5 / 10.0.1.6) on the K3s cluster nodes via Terraform configuration to guarantee static proxy alignment. Already defined on Terraform now on main.tf.

Bootstrap Variable Overrides: Utilized high-priority Ansible Extra Variables (-e "ansible_user=lab.admin") to bypass default inventory configurations and establish the baseline OS environment on the fresh gateway.

Core Hardening & User Provisioning: Orchestrated package upgrades, UFW firewall active matrices, and initialized the permanent ops user automation profile via deploy-k3s.yml directly across the secure gateway SSH proxy tunnel.

Automated Configuration Drift Protection: Configured a native Ansible handler for Caddy. Now, updates to subdomains inside the Write Caddyfile task automatically trigger a live container reload (caddy reload), preventing runtime service downtime.

K3s Dynamic Storage Provisioning: Deployed a persistent volume claim (memos-pvc.yaml) using K3s's built-in local-path provisioner, locking down 2Gi of capacity.

Stateful Application Orchestration: Deployed the Memos note-taking application container linked to the persistent volume claim. Verified data persistence across forced pod destructions (kubectl delete pod).

Cloud-to-Cluster Routing Engine: Implemented modern Traefik Ingress routes (memos-ingress.yaml and whoami-ingress.yaml) pointing to their cluster services, paired with edge proxy rules in the Ansible Caddy layout to securely route external traffic from gairelab.duckdns.org subdomains directly into the internal K3s node network.

💻 Disaster Recovery Checklist for a New Laptop
Looking closely at your attached folder tree, your .gitignore is successfully keeping sensitive states and configurations local. If your current machine completely dies and you pull this repository down onto a brand-new laptop, the repository will intentionally be missing your structural states and keys.

Here is the exact checklist of the files you will need to manually recreate or copy from your secure backups to get the lab automation engine running again:

1. In the terraform/ Folder
terraform.tfvars

What it holds: Your live Azure subscription IDs, cloud tenant credentials, and the administrative root user passwords used to provision the baseline VMs.

terraform.tfstate & terraform.tfstate.backup

What it holds: The cryptographic map tracking exactly which real Azure hardware resources belong to your configuration files.

Note: If you don't have this file on a new laptop, running terraform apply will think nothing exists and try to build duplicate VMs, causing a crash. You either need to back this state file up securely or run terraform import for your resources.

2. In the ansible/ Folder
ansible/vars/secrets.yml

What it holds: Your unencrypted variables like vault_duckdns_token and plaintext setup targets like your hashed/plaintext passwords.

ansible/playbooks/.kube/config

What it holds: Your administrative authentication token context needed to issue remote commands down to your K3s cluster nodes using your local control utility engines.

ansible/k3s-manifests/ Configurations

What it holds: Your core Kubernetes application deployment files (memos-*.yaml and whoami-*.yaml). Unlike states/secrets, these generic application manifests are safely checked directly into your repository tracking branch.

3. In Your Local Machine User Profile (~/.ssh/)
~/.ssh/azure-lab-private-key

What it holds: The private OpenSSH key pair file required to pass through the front gateway and decrypt the target authentication chains inside your automated script manifests. Without this local file, every single connection handshake will fail.