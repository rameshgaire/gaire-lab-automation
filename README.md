gaire-lab-automation

Infrastructure-as-code automation lab: Azure cloud infrastructure, a K3s Kubernetes cluster, a Dockerised application stack, and a single HTTPS edge — all provisioned and configured with zero manual steps via Terraform and Ansible.

Live endpoints:


https://n8n.gairelab.duckdns.org — automation workflows
https://chat.gairelab.duckdns.org — private AI (Open WebUI + Ollama)
https://portainer.gairelab.duckdns.org — Docker management
https://ollama.gairelab.duckdns.org — AI model API (basic auth)
https://memos.gairelab.duckdns.org — Kubernetes-hosted notes app
https://whoami.gairelab.duckdns.org — Kubernetes test app



Architecture

There is exactly one public entry point: Caddy, running on the application VM. Everything else — including the entire K3s cluster — is reached privately over the Azure VNet. Nothing else needs to be (or is) exposed to the internet.

Internet
   |
   v
gairelab.duckdns.org  (DuckDNS wildcard -> application VM's static public IP)
   |
   v
Caddy  (application VM - TLS termination, cert issuance via DuckDNS DNS-01)
   |
   |-- n8n.gairelab.duckdns.org        -> n8n:5678          (Docker, same VM)
   |-- chat.gairelab.duckdns.org       -> open-webui:8080    (Docker, same VM)
   |-- portainer.gairelab.duckdns.org  -> portainer:9443     (Docker, same VM)
   |-- ollama.gairelab.duckdns.org     -> ollama:11434       (Docker, same VM, basic auth)
   |
   `-- memos.gairelab.duckdns.org   --,
       whoami.gairelab.duckdns.org  --+--> 10.0.1.5:80 (K3s master, private VNet IP)
                                          |
                                          v
                                       Traefik (K3s built-in ingress)
                                          |
                                          v
                                       routes by hostname -> correct Pod

Why this matters for a rebuild: the K3s nodes do not need to be internet-facing at all for ingress to work — Caddy reaches the master node's private IP (10.0.1.5) over the VNet. Any public IPs / NSG rules opening ports 80 or 443 on the K3s nodes are leftover from an earlier design and are not required by this architecture (see Known limitations below).

Certificate issuance — DNS-01, not HTTP-01

Caddy's global config block uses the DuckDNS ACME plugin:

{
    email you@example.com
    acme_dns duckdns <token>
}

This means Caddy proves domain ownership to Let's Encrypt by creating a DNS TXT record directly via the DuckDNS API — Let's Encrypt never needs to reach your VM over HTTP to issue a certificate. Certificate issuance is therefore not affected by DNS propagation delay.

What is affected by propagation: after a rebuild, your own and visitors' DNS resolvers still need to pick up the new IP for gairelab.duckdns.org before requests reach the new VM at all. With DuckDNS's short TTL this is usually seconds to a couple of minutes — but it's worth a short wait-and-retry if a fresh deploy seems unreachable immediately after terraform apply.

Component breakdown

ComponentToolLives inCloud infrastructureTerraformterraform/Server configurationAnsibleansible/playbooks/Docker stack + Caddy (incl. K3s proxy routes)Ansibleansible/playbooks/deploy-stack.ymlK3s cluster bootstrapAnsibleansible/playbooks/deploy-k3s.ymlKubernetes applicationskubectl manifestsansible/k3s-manifests/Infrastructure monitoringPythonhealth_check.pyCI pipelineGitHub Actions.github/workflows/


What is tracked in Git vs what is not

This repo is public. Nothing secret is committed. Files containing credentials, state, or keys are excluded via .gitignore and must be restored from a secure backup — see Disaster recovery below.

Tracked in Git (yes)Not tracked - local only (no)terraform/*.tfterraform/terraform.tfvarsansible/playbooks/*.ymlterraform/terraform.tfstate*ansible/k3s-manifests/*.yamlansible/playbooks/vars/secrets.ymlhealth_check.pyansible/inventory/hosts.yml.github/workflows/*.yml~/.kube/config (on control node)~/.ssh/azure-lab-private-key (on control node)

The Caddy to K3s reverse-proxy routes (the memos / whoami blocks shown above) are written from the Ansible template inside deploy-stack.yml, not hand-edited on the VM. Every ansible-playbook playbooks/deploy-stack.yml run regenerates /etc/caddy/Caddyfile from that template and reloads Caddy — so this part of the architecture is fully reproducible by design.


Prerequisites


An Azure account with an active subscription
A Linux control node to run Ansible from (Ansible does not run natively on Windows; a free-tier GCP e2-micro works well)
Terraform and Azure CLI installed locally where you run terraform apply (logged in via az login)
A free DuckDNS domain and token
An SSH key pair in RSA format generated on your control node (Azure VM login does not support ed25519)



Disaster recovery checklist

If your control node or laptop is wiped, restore these from your own secure backup (password manager / encrypted vault) before running anything. Git will not bring these back — that's intentional.

FileLocationWhat it holdsterraform.tfvarsterraform/Azure subscription ID, VM admin credentials, your SSH public key, alert emailterraform.tfstate + .backupterraform/Terraform's map of which real Azure resources belong to your config. Without it, terraform apply will try to create duplicates.secrets.ymlansible/playbooks/vars/DuckDNS token, Ollama admin passwordhosts.ymlansible/inventory/VM IP addresses and SSH connection detailsazure-lab-private-key~/.ssh/ on control nodePrivate half of the SSH key your Azure VMs trust. Nothing connects without it.~/.kube/configcontrol nodeCredentials kubectl uses to talk to the K3s cluster


Warning: K3s data is not backed up. Persistent storage for cluster apps (e.g. memos-pvc) uses K3s's local-path provisioner, which writes directly to the K3s worker node's local disk. Destroying that VM destroys the data with it. If an app's data matters, back it up (e.g. kubectl cp, or export from the app itself) before running terraform destroy.




Step-by-step rebuild (from a clean Azure subscription)

Follow this order - each phase depends on the one before it.

Phase 1 - Provision cloud infrastructure (Terraform)

Run from your local machine, not the control node.


Restore terraform/terraform.tfvars from backup (or recreate it - see variables.tf for required fields).
Initialise and apply:


bash   cd terraform/
   terraform init
   terraform apply


Note the application VM's static public IP from the output.


Phase 2 - Point Ansible at the new infrastructure

Run from your control node.


Update ansible/inventory/hosts.yml with the new public IP (both places it appears). The K3s nodes' private IPs are fixed in Terraform (10.0.1.5 master / 10.0.1.6 worker) and don't change between rebuilds.
Confirm connectivity:


bash   cd ansible/
   ansible azure_lab_vm -m ping

Phase 3 - Configure the application VM


Harden the OS, create the ops automation user, configure the firewall:


bash   ansible-playbook playbooks/base-setup.yml


Deploy the Docker stack - installs Docker, builds the DuckDNS-enabled Caddy image, writes the Caddyfile (including the K3s proxy routes), deploys n8n / Ollama / Open WebUI / Portainer, requests SSL certificates, pulls the phi3 model:


bash   ansible-playbook playbooks/deploy-stack.yml


Verify DNS has caught up before relying on the public hostnames (see the DNS-01 note above):


bash   nslookup gairelab.duckdns.org
   # should return the new IP from step 3 - if not, wait a minute and retry

Phase 4 - Provision the K3s cluster


Run base hardening against the K3s nodes:


bash   ansible-playbook playbooks/base-setup.yml -e "target=k3s_cluster"


Bootstrap the cluster - installs K3s server on the master, joins the worker:


bash    ansible-playbook playbooks/deploy-k3s.yml


Confirm both nodes are Ready:


bash    kubectl get nodes


Phase 4.5 — Sync and Proxy Cluster Credentials (The Rebuild Twist) | tar -cf - -C ~/gaire-lab-automation/ansible k3s-manifests | ssh -o ProxyCommand="ssh -W %h:%p -q -i ~/.ssh/azure-lab-private-key -o StrictHostKeyChecking=no ops@20.70.114.78" -i ~/.ssh/azure-lab-private-key ops@10.0.1.5 "tar -xf - -C /tmp && sudo kubectl apply -f /tmp/k3s-manifests && rm -rf /tmp/k3s-manifests"


Because the K3s cluster lives completely isolated inside the private Azure VNet, your external control node cannot reach 10.0.1.5 directly to run cluster commands. We must fetch the credentials using a nested jump check and proxy our local kubectl traffic through an SSH SOCKS5 tunnel.

Fetch the new token configuration from your control node using your local SSH key via the gateway:

Bash
ssh -i ~/.ssh/azure-lab-private-key -o ProxyCommand="ssh -i ~/.ssh/azure-lab-private-key -W %h:%p ops@<APPLICATION_VM_PUBLIC_IP>" ops@10.0.1.5 "sudo cat /etc/rancher/k3s/k3s.yaml" > ~/.kube/config
Update the endpoint reference from localhost loopback to the cluster master's private VNet IP:

Bash
sed -i 's/127.0.0.1/10.0.1.5/g' ~/.kube/config
chmod 600 ~/.kube/config
Establish a dynamic SOCKS5 routing tunnel to bridge your control node terminal into the private Azure VNet:

Bash
ssh -i ~/.ssh/azure-lab-private-key -D 1080 -N -f ops@<APPLICATION_VM_PUBLIC_IP>
Verify node communication by routing your query through the proxy session:

Bash
HTTPS_PROXY=socks5://127.0.0.1:1080 kubectl get nodes
(Optional: Run export HTTPS_PROXY=socks5://127.0.0.1:1080 to keep the proxy active for your entire current terminal window).



Phase 5 - Deploy Kubernetes applications

Service and Deployment first, storage before the app that consumes it, Ingress last:

bashcd ansible/k3s-manifests/

kubectl apply -f whoami-service.yaml
kubectl apply -f whoami-deployment.yaml
kubectl apply -f whoami-ingress.yaml

kubectl apply -f memos-pvc.yaml
kubectl apply -f memos-deployment.yaml
kubectl apply -f memos-ingress.yaml

Phase 6 - Verify

bashkubectl get pods -A
kubectl get ingress -A
python3 health_check.py

Then visit each endpoint listed at the top of this README and confirm it loads.


Known limitations / possible improvements


K3s ingress has no TLS of its own. Traffic from Caddy to the K3s master (10.0.1.5:80) is plain HTTP - acceptable here because it never leaves the private VNet, but worth knowing. Adding cert-manager + a ClusterIssuer would let the cluster issue its own certificates if it's ever exposed directly.
Ingress is pinned to the master node only. Traefik runs on both K3s nodes (svclb-traefik is a daemonset), but Caddy only proxies to 10.0.1.5. If the master is down, memos/whoami become unreachable even though the worker's Traefik instance is healthy. Pointing Caddy at both nodes (or a load balancer in front of them) would fix this.
K3s node public IPs / NSG rules for ports 80 and 443 are unused under the current architecture and could be removed or tightened to SSH-only (and 6443 for the K3s API) for a smaller attack surface.



Tear-down

bashcd terraform/
terraform destroy

This removes everything Terraform created from Azure. Your code, manifests, and playbooks stay in GitHub untouched - re-running Step-by-step rebuild above restores the full environment.
