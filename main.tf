# Configure the Azure provider
provider "azurerm" {
  features {}
}

# Create a resource group
resource "azurerm_resource_group" "dev" {
  name     = var.resource_group_name # Name of the resource group from variables
  location = var.location            # Location of the resource group from variables
}

# Create a virtual network
resource "azurerm_virtual_network" "dev" {
  name                = "dev-network"                            # Name of the virtual network
  address_space       = ["10.0.0.0/16"]                          # Address space for the virtual network
  location            = azurerm_resource_group.dev.location      # Location from the resource group
  resource_group_name = azurerm_resource_group.dev.name          # Resource group name
}

# Create a subnet within the virtual network
resource "azurerm_subnet" "dev" {
  name                 = "dev-subnet"                              # Name of the subnet
  resource_group_name  = azurerm_resource_group.dev.name           # Resource group name
  virtual_network_name = azurerm_virtual_network.dev.name          # Virtual network name
  address_prefixes     = ["10.0.1.0/24"]                           # Address prefix for the subnet
}

# Create a network security group
resource "azurerm_network_security_group" "dev" {
  name                = "dev-nsg"                                  # Name of the network security group
  location            = azurerm_resource_group.dev.location        # Location from the resource group
  resource_group_name = azurerm_resource_group.dev.name            # Resource group name

  # Define an inbound security rule to allow SSH
  security_rule {
    name                       = "allow-ssh"                        # Name of the security rule
    priority                   = 1001                               # Priority of the rule
    direction                  = "Inbound"                          # Direction of the traffic
    access                     = "Allow"                            # Access type
    protocol                   = "Tcp"                              # Protocol type
    source_port_range          = "*"                                # Source port range
    destination_port_range     = "22"                               # Destination port (SSH)
    source_address_prefix      = "10.0.1.0/24"                      # Source address prefix
    destination_address_prefix = "*"                                # Destination address prefix
  }

  # Define an outbound security rule to allow SSH
  security_rule {
    name                       = "allow-ssh-egress"                 # Name of the security rule
    priority                   = 1002                               # Priority of the rule
    direction                  = "Outbound"                         # Direction of the traffic
    access                     = "Allow"                            # Access type
    protocol                   = "Tcp"                              # Protocol type
    source_port_range          = "*"                                # Source port range
    destination_port_range     = "22"                               # Destination port (SSH)
    source_address_prefix      = "*"                                # Source address prefix
    destination_address_prefix = "10.0.1.0/24"                      # Destination address prefix
  }
}

# Associate the network security group with the subnet
resource "azurerm_subnet_network_security_group_association" "dev" {
  subnet_id                 = azurerm_subnet.dev.id                # Subnet ID
  network_security_group_id = azurerm_network_security_group.dev.id # Network security group ID
}

# Create network interfaces
resource "azurerm_network_interface" "dev" {
  count               = var.vm_count                                # Number of network interfaces to create
  name                = "dev-nic-${count.index}"                    # Name of the network interface
  location            = azurerm_resource_group.dev.location         # Location from the resource group
  resource_group_name = azurerm_resource_group.dev.name             # Resource group name

  ip_configuration {
    name                          = "internal"                      # Name of the IP configuration
    subnet_id                     = azurerm_subnet.dev.id           # Subnet ID
    private_ip_address_allocation = "Dynamic"                       # IP address allocation method
  }
}

# Generate random passwords for VMs
resource "random_password" "admin_password" {
  count           = var.vm_count                                    # Number of passwords to generate
  length          = 16                                              # Length of the passwords
  special         = true                                            # Include special characters
  override_special = "_%@"                                          # Override special characters
}

# Create virtual machines
resource "azurerm_virtual_machine" "dev" {
  count               = var.vm_count                                # Number of VMs to create
  name                = "dev-vm-${count.index}"                     # Name of the VM
  location            = azurerm_resource_group.dev.location         # Location from the resource group
  resource_group_name = azurerm_resource_group.dev.name             # Resource group name
  network_interface_ids = [                                         # Network interface IDs
    azurerm_network_interface.dev[count.index].id
  ]
  vm_size             = var.vm_size                                 # VM size from variables

  storage_os_disk {
    name              = "dev-os-disk-${count.index}"                # Name of the OS disk
    caching           = "ReadWrite"                                 # Caching type
    create_option     = "FromImage"                                 # Create option
    managed_disk_type = "Standard_LRS"                              # Managed disk type
    disk_size_gb      = var.os_disk_sizes[count.index]              # Disk size from variables
  }

  storage_image_reference {
    publisher = var.vm_os_images[count.index].publisher             # Uses OS image publisher from the list
    offer     = var.vm_os_images[count.index].offer                 # Uses OS image offer from the list
    sku       = var.vm_os_images[count.index].sku                   # Uses OS image SKU from the list
    version   = var.vm_os_images[count.index].version               # Uses OS image version from the list
  }

  os_profile {
    computer_name  = "dev-vm-${count.index}"                        # Computer name
    admin_username = var.admin_username                             # Admin username from variables
    admin_password = random_password.admin_password[count.index].result # Admin password from generated passwords
  }

  os_profile_linux_config {
    disable_password_authentication = false                         # Enable password authentication
  }

  tags = {
    environment = "Development"                                     # Tag for the environment
  }

  # Provisioner to run commands on the VM after creation
  provisioner "remote-exec" {
    inline = [
      "echo 'Running ping test from VM ${count.index}'",             # Command to echo running ping test
      "sudo apt-get update",                                         # Update package lists
      "sudo apt-get install -y inetutils-ping",                      # Install ping utility
      "for ip in $(curl -s http://169.254.169.254/metadata/instance?api-version=2019-06-01&format=json | jq -r '.network.interface[0].ipv4.ipAddress[].privateIpAddress'); do if [ \"$ip\" != \"$(hostname -I | awk '{print $1}')\" ]; then ping -c 4 $ip; fi; done" # Loop to ping other VMs
    ]

    connection {
      type        = "ssh"                                            # Connection type
      user        = var.admin_username                               # Username for SSH
      password    = random_password.admin_password[count.index].result # Password for SSH
      host        = azurerm_network_interface.dev[count.index].private_ip_address # Host IP address
    }
  }
}

# Local provisioner to run ping tests from the local machine
resource "null_resource" "ping_test" {
  provisioner "local-exec" {
    command = <<EOT
      for ip in $(terraform output -json vm_private_ips | jq -r '.[]'); do
        echo "Pinging $ip";                                           # Command to echo pinging IP
        for i in {0..3}; do                                           # Loop to ping each IP 4 times
          ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa ${var.admin_username}@$ip "ping -c 4 $ip"; # SSH into VM and ping
        done
      done
    EOT
  }
}
