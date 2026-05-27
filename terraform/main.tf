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
# Equivalent to your SonicWall access rules but for this VM only
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
    name                       = "Allow-Portainer"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-n8n"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5678"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-Ollama"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "11434"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-OpenWebUI"
    priority                   = 1005
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000"
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

# The VM itself — Ubuntu 22.04, Standard_B1s (free tier eligible)
resource "azurerm_linux_virtual_machine" "lab" {
  name                = "gaire-lab-vm"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  size                = var.vm_size  # 1 vCPU, 1GB RAM — free tier
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  # Allow password auth — use SSH keys in production
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.lab.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
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
    start_date = "2026-05-01T00:00:00Z"
    end_date   = "2027-05-01T00:00:00Z"
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