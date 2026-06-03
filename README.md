# gaire-lab-automation
gaire-lab-automation

Run Terraform,
Update Public IP in 2 places inside hosts file in ansible>inventory>hosts.yml
ansible azure_lab_vm -m ping -e "ansible_user=lab.admin"
ansible-playbook playbooks/base-setup.yml -e "ansible_user=lab.admin"
ansible-playbook playbooks/deploy-k3s.yml
ansible-playbook playbooks/deploy-stack.yml


