# outputs.tf

output "vm_admin_passwords" {
  value = [for p in random_password.admin_password : p.result]
  sensitive = true
}

output "vm_private_ips" {
  value = azurerm_network_interface.dev[*].private_ip_address
}
