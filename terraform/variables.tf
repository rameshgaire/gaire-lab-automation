# variables.tf
# Defines all configurable inputs for this Terraform configuration
# Think of these like function parameters — values defined here,
# actual values supplied in terraform.tfvars

variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  type        = string
  default     = "gaire-lab-rg"
}

variable "location" {
  description = "Azure region to deploy resources"
  type        = string
  default     = "australiasoutheast"
}

variable "environment" {
  description = "Environment tag — lab, dev, prod"
  type        = string
  default     = "lab"
}

variable "admin_username" {
  description = "Admin username for the VM"
  type        = string
  default     = "lab.admin"
}

variable "admin_password" {
  description = "Admin password for the VM"
  type        = string
  sensitive   = true  # Terraform will never print this in logs
}

variable "vm_size" {
  description = "The size/SKU of the Virtual Machine"
  type        = string
  default     = "Standard_B2ats_v2" # 💸 100% Free Tier Eligible AMD SKU
}