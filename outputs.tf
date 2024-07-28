# outputs.tf

# Define an output variable for VM admin passwords
output "vm_admin_passwords" {
  # Set the value to a list of results from each random password generated for VMs
  value = [for p in random_password.admin_password : p.result]
  
  # Mark the output as sensitive to prevent it from being displayed in logs or the console
  sensitive = true
}

# Define an output variable for VM private IP addresses
output "vm_private_ips" {
  # Set the value to the list of private IP addresses of all network interfaces created for VMs
  value = azurerm_network_interface.dev[*].private_ip_address
}

