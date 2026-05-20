# outputs.tf
# What Terraform displays after successfully applying
# Like the return value of a function

output "resource_group_name" {
  description = "Name of the created resource group"
  value       = azurerm_resource_group.lab.name
}

output "vm_public_ip" {
  description = "Public IP address of the lab VM"
  value       = azurerm_public_ip.lab.ip_address
}

output "vm_name" {
  description = "Name of the created VM"
  value       = azurerm_linux_virtual_machine.lab.name
}

output "ssh_command" {
  description = "SSH command to connect to the VM"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.lab.ip_address}"
}