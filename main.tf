terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.56.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "openbalena" {
  location = "West Europe"
  name     = "OpenBalena"
}

resource "azurerm_virtual_network" "openbalena" {
  name                = "openbalena-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.openbalena.location
  resource_group_name = azurerm_resource_group.openbalena.name
}

resource "azurerm_subnet" "example" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.openbalena.name
  virtual_network_name = azurerm_virtual_network.openbalena.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "public_ip" {
  name                = "openbalena-public-ip"
  resource_group_name = azurerm_resource_group.openbalena.name
  location            = azurerm_resource_group.openbalena.location
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "openbalena" {
  name                = "openbalena-nic"
  location            = azurerm_resource_group.openbalena.location
  resource_group_name = azurerm_resource_group.openbalena.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.example.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

resource "azurerm_network_security_group" "openbalena_security_group" {
  name                = "openbalena-security-group"
  location            = azurerm_resource_group.openbalena.location
  resource_group_name = azurerm_resource_group.openbalena.name

  security_rule {
    name                       = "allow-openbalena"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["22", "80", "443", "3128"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "openbalena_security_group_association" {
  network_interface_id      = azurerm_network_interface.openbalena.id
  network_security_group_id = azurerm_network_security_group.openbalena_security_group.id
}

resource "tls_private_key" "openbalena_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_linux_virtual_machine" "openbalena" {
  name                  = "OpenBalena"
  resource_group_name   = azurerm_resource_group.openbalena.name
  location              = azurerm_resource_group.openbalena.location
  size                  = "Standard_F2s_v2"
  admin_username        = "ubuntu"
  network_interface_ids = [
    azurerm_network_interface.openbalena.id,
  ]

  admin_ssh_key {
    username   = "ubuntu"
    public_key = tls_private_key.openbalena_ssh_key.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
}