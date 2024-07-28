# variables.tf

 variable "resource_group_name" {
  description = "The name of the resource group"  # Describes the purpose of the variable
  default     = "dev-resources"                   # Default value for the resource group name
}

 variable "location" {
  description = "The Azure region to deploy resources in"  # Describes where resources will be deployed
  default     = "West Europe"                              # Default Azure region for deployment
}

 variable "vm_count" {
  description = "Number of VMs to create"  # Describes how many VMs to create
  default     = 4                         # Default number of VMs to create
}

 variable "admin_username" {
  description = "Admin username for the VMs"  # Describes the admin username for VMs
  default     = "adminuser"                   # Default admin username for VMs
}

 variable "vm_size" {
  description = "The size of the VM instances"  # Describes the VM size/type
  default     = "Standard_A1_v2"                # Default VM size/type
}

 variable "os_disk_sizes" {
  description = "List of OS disk sizes for each VM (in GB)"  # Describes the list of OS disk sizes for VMs
  type        = list(number)                                 # Specifies the type of variable as a list of numbers
  default     = [30, 31, 35, 34]                             # Default list of OS disk sizes for the VMs
}

variable "vm_os_images" {
  description = "List of OS image configurations for each VM"
  type = list(object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  }))
  default = [
    {
      publisher = "Canonical"                    # Publisher of the OS image                    
      offer     = "0001-com-ubuntu-server-focal" # Offer name of the OS image.
      sku       = "20_04-lts"                    # Verison or edition of offer.
      version   = "latest"                       # Version of the OS image.
    }
  ]
}
