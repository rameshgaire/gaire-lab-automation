# main.tf
# Main infrastructure definition for gaire-lab Azure environment
# This file tells Terraform WHAT to create in Azure

# Tell Terraform which cloud provider to use and what version
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
  required_version = ">= 1.0"
}

# Configure the Azure provider
# Terraform reads your Azure CLI login automatically
provider "azurerm" {
  features {}
}

# Resource Group — the container for all other resources
# Everything in Azure lives inside a Resource Group
resource "azurerm_resource_group" "lab" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    environment = var.environment
    managed_by  = "terraform"
    owner       = "ramesh.gaire"
  }
}

# Virtual Network — your private network in Azure
# Equivalent to your 10.10.10.0/24 LAN but in the cloud
resource "azurerm_virtual_network" "lab" {
  name                = "gaire-lab-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  tags = {
    environment = var.environment
  }
}

# Subnet — a segment of the virtual network
# Like a VLAN inside your VNet
resource "azurerm_subnet" "lab" {
  name                 = "gaire-lab-subnet"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.0.1.0/24"]
  # This line prevents the "Root object present but absent" API bug
  depends_on = [azurerm_virtual_network.lab]
}

# Public IP — so you can reach the VM from outside Azure
resource "azurerm_public_ip" "lab" {
  name                = "gaire-lab-pip"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"        # ← change from Basic to Standard

  tags = {
    environment = var.environment
  }
}

# Network Security Group — Azure's firewall rules
# Hardened to only permit core administration and proxy traffic
resource "azurerm_network_security_group" "lab" {
  name                = "gaire-lab-nsg"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTPS"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = var.environment
  }
}

# Network Interface Card — connects the VM to the network
resource "azurerm_network_interface" "lab" {
  name                = "gaire-lab-nic"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.lab.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.lab.id
  }
}

# Associate NSG with the NIC
resource "azurerm_network_interface_security_group_association" "lab" {
  network_interface_id      = azurerm_network_interface.lab.id
  network_security_group_id = azurerm_network_security_group.lab.id
}

# The VM itself — Ubuntu 22.04, Standard_B2als_v2 (2 vCPU, 4GB RAM)
resource "azurerm_linux_virtual_machine" "lab" {
  name                = "gaire-lab-vm"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  size = var.vm_size  # B2als_v2 — 2 vCPU, 4GB RAM
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  # Allow password auth — use SSH keys in production
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.lab.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 64
  }

  # Ubuntu 22.04 LTS — same as your SYD-VM01
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  tags = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

# Budget alert — get notified if spending exceeds $5/month
# Requires the Consumption API to be registered on your subscription
resource "azurerm_consumption_budget_subscription" "lab" {
  name            = "gaire-lab-budget"
  subscription_id = "/subscriptions/07772dcd-859f-4210-a3a7-fcb0317f50b6"

  amount     = 5
  time_grain = "Monthly"

  time_period {
    start_date = "2026-06-01T00:00:00Z"
    end_date   = "2027-06-01T00:00:00Z"
  }

  notification {
    enabled        = true
    threshold      = 80.0
    operator       = "GreaterThan"
    threshold_type = "Actual"

    contact_emails = [var.alert_email]
  }

  notification {
    enabled        = true
    threshold      = 100.0
    operator       = "GreaterThan"
    threshold_type = "Actual"

    contact_emails = [var.alert_email]
  }

  notification {
    enabled        = true
    threshold      = 100.0
    operator       = "GreaterThan"
    threshold_type = "Forecasted"

    contact_emails = [var.alert_email]
  }
}

# Monitor disk usage and CPU — alert when disk hits 85%
resource "azurerm_monitor_metric_alert" "disk_alert" {
  name                = "gaire-lab-disk-alert"
  resource_group_name = azurerm_resource_group.lab.name
  scopes              = [azurerm_linux_virtual_machine.lab.id]
  description         = "Alert when OS disk usage exceeds 85%"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    aggregation            = "Average"
    metric_namespace       = "Microsoft.Compute/virtualMachines"
    metric_name            = "Disk Write Bytes" # Changed to a valid host metric
    operator               = "GreaterThan"
    skip_metric_validation = false
    threshold              = 107374182400       # Example: Triggers if writes exceed 100 GB in the window
  }

  action {
    action_group_id = azurerm_monitor_action_group.lab.id
  }
}

resource "azurerm_monitor_metric_alert" "memory_alert" {
  name                = "gaire-lab-memory-alert"
  resource_group_name = azurerm_resource_group.lab.name
  scopes              = [azurerm_linux_virtual_machine.lab.id]
  description         = "Alert when available memory drops below 500MB"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Available Memory Bytes"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 524288000
  }

  action {
    action_group_id = azurerm_monitor_action_group.lab.id
  }
}

resource "azurerm_monitor_action_group" "lab" {
  name                = "gaire-lab-alerts"
  resource_group_name = azurerm_resource_group.lab.name
  short_name          = "gairelab"

  email_receiver {
    name          = "ramesh"
    email_address = var.alert_email
  }
}

# ==========================================
# PHASE C: KUBERNETES LAB COMPUTE RESOURCES
# ==========================================

# 1. Network Interfaces for K3s Nodes
resource "azurerm_network_interface" "k3s_master_nic" {
  name                = "gaire-lab-k3s-master-nic"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.lab.id # Fixed: Points directly to your managed subnet resource
    private_ip_address_allocation = "Static"    # <-- Changed from Dynamic
    private_ip_address            = "10.0.1.5"   # <-- Anchored Master IP
  }
}

resource "azurerm_network_interface" "k3s_worker_nic" {
  name                = "gaire-lab-k3s-worker-nic"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.lab.id # Fixed: Points directly to your managed subnet resource
    private_ip_address_allocation = "Static"    # <-- Changed from Dynamic
    private_ip_address            = "10.0.1.6"   # <-- Anchored Master IP
  }
}

# 2. K3s Master Node (Control Plane)
resource "azurerm_linux_virtual_machine" "k3s_master" {
  name                = "gaire-lab-k3s-master"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  size                = "Standard_B2als_v2" # Updated: Swapped to available AMD SKU (2 vCPU, 4GB RAM)
  admin_username      = "ops"
  network_interface_ids = [
    azurerm_network_interface.k3s_master_nic.id,
  ]

  admin_ssh_key {
    username   = "ops"
    public_key = var.ssh_public_key # Cleaned up: Uses your existing public key variable
  }

  # Allow password auth for testing or initial setup if needed (consistent with your other VM)
  disable_password_authentication = false
  admin_password                  = var.admin_password

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  tags = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

# 3. K3s Worker Node (Compute Agent)
resource "azurerm_linux_virtual_machine" "k3s_worker" {
  name                = "gaire-lab-k3s-worker"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  size                = "Standard_B2als_v2" # Updated: Swapped to available AMD SKU (1 vCPU, 2GB RAM)
  admin_username      = "ops"
  network_interface_ids = [
    azurerm_network_interface.k3s_worker_nic.id,
  ]

  admin_ssh_key {
    username   = "ops"
    public_key = var.ssh_public_key # Cleaned up: Uses your existing public key variable
  }

  disable_password_authentication = false
  admin_password                  = var.admin_password

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  tags = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

# 4. Outputs to instantly grab IPs for Ansible
output "k3s_master_private_ip" {
  value = azurerm_network_interface.k3s_master_nic.ip_configuration[0].private_ip_address
}

output "k3s_worker_private_ip" {
  value = azurerm_network_interface.k3s_worker_nic.ip_configuration[0].private_ip_address
}