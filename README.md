main.tf description.
In this readme I will describe the strategy for setting up the Azure infrastructure using Terraform :
    - Provider Configuration: Configured the Azure provider to enable interaction with Azure resources.
    - Resource Group Creation: Create a resource group to hold all related resources.
    - Network Setup:
        - Created a virtual network to provide an isolated network environment.
        - Created a subnet within the virtual network to segment the network.
    - Security Configuration:
        - Created a network security group with rules to allow inbound and outbound SSH traffic.
        - Associated the NSG with the subnet to apply the security rules.
    - Network Interfaces: Created network interfaces for each virtual machine, associating them with the subnet.
    - Random Password Generation: Generated random passwords for the VMs' admin accounts.
    - For the Virtual Machines:
        - Created VMs, specifying configurations such as size, disk, and image.
        - Assigned network interfaces and generated admin passwords for the VMs.
        - Used a provisioner to run initial setup commands on the VMs, including a ping test to verify network connectivity. Which unfortunately failed, but will do a revision on the code to fix this.


