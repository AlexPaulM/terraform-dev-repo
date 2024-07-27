# variables.tf

variable "resource_group_name" {
  description = "The name of the resource group"
  default     = "dev-resources"
}

variable "location" {
  description = "The Azure region to deploy resources in"
  default     = "West Europe"
}

variable "vm_count" {
  description = "Number of VMs to create"
  default     = 4
}

variable "admin_username" {
  description = "Admin username for the VMs"
  default     = "adminuser"
}

variable "vm_size" {
  description = "The size of the VM instances"
  default     = "Standard_A1_v2"
}

variable "os_disk_sizes" {
  description = "List of OS disk sizes for each VM (in GB)"
  type        = list(number)
  default     = [30, 31, 35, 34]
}