output "openbalena_ssh_private_key" {
  value = tls_private_key.openbalena_ssh_key.private_key_openssh
  sensitive = true
}

output "openbalena_host" {
  value = azurerm_public_ip.public_ip.ip_address
}