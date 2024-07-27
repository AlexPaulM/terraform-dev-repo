# main.tf

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "dev" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "dev" {
  name                = "dev-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name
}

resource "azurerm_subnet" "dev" {
  name                 = "dev-subnet"
  resource_group_name  = azurerm_resource_group.dev.name
  virtual_network_name = azurerm_virtual_network.dev.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "dev" {
  name                = "dev-nsg"
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name

  security_rule {
    name                       = "allow-ssh"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.0.1.0/24"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-ssh-egress"
    priority                   = 1002
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "10.0.1.0/24"
  }
}

resource "azurerm_subnet_network_security_group_association" "dev" {
  subnet_id                 = azurerm_subnet.dev.id
  network_security_group_id = azurerm_network_security_group.dev.id
}

resource "azurerm_network_interface" "dev" {
  count               = var.vm_count
  name                = "dev-nic-${count.index}"
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.dev.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "random_password" "admin_password" {
  count           = var.vm_count
  length          = 16
  special         = true
  override_special = "_%@"
}

resource "azurerm_virtual_machine" "dev" {
  count               = var.vm_count
  name                = "dev-vm-${count.index}"
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name
  network_interface_ids = [
    azurerm_network_interface.dev[count.index].id
  ]
  vm_size             = var.vm_size

  storage_os_disk {
    name              = "dev-os-disk-${count.index}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
    disk_size_gb      = var.os_disk_sizes[count.index]
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }

  os_profile {
    computer_name  = "dev-vm-${count.index}"
    admin_username = var.admin_username
    admin_password = random_password.admin_password[count.index].result
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags = {
    environment = "Development"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Running ping test from VM ${count.index}'",
      "sudo apt-get update",
      "sudo apt-get install -y inetutils-ping",
      "for ip in $(curl -s http://169.254.169.254/metadata/instance?api-version=2019-06-01&format=json | jq -r '.network.interface[0].ipv4.ipAddress[].privateIpAddress'); do if [ \"$ip\" != \"$(hostname -I | awk '{print $1}')\" ]; then ping -c 4 $ip; fi; done"
    ]

    connection {
      type        = "ssh"
      user        = var.admin_username
      password    = random_password.admin_password[count.index].result
      host        = azurerm_network_interface.dev[count.index].private_ip_address
    }
  }
}

resource "null_resource" "ping_test" {
  provisioner "local-exec" {
    command = <<EOT
      for ip in $(terraform output -json vm_private_ips | jq -r '.[]'); do
        echo "Pinging $ip";
        for i in {0..3}; do
          ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa ${var.admin_username}@$ip "ping -c 4 $ip";
        done
      done
    EOT
  }
}
