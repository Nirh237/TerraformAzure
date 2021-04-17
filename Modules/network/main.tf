
#Create resource group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location 
}

#Create virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = "vnetTF"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = var.vnet
}

#Create subnets - Public and Private
  resource "azurerm_subnet" "publicSubnet" {
  name                 = "public-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.0.0/24"]
  }


  resource "azurerm_subnet" "privateSubnet" {
  name                 = "private-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
  }



#Create public ip - Public Load Balancer IP
  resource "azurerm_public_ip" "publicIPLB" {
 name                         = "publicIPForLB"
 location                     = azurerm_resource_group.rg.location
 resource_group_name          = azurerm_resource_group.rg.name
 allocation_method            = "Static"
}

#Create public ip - Public IP
  resource "azurerm_public_ip" "publicIP" {
 name                         = "publicIP"
 location                     = azurerm_resource_group.rg.location
 resource_group_name          = azurerm_resource_group.rg.name
 allocation_method            = "Static"
}


#Create Load Balancer - Public Load Balancer
resource "azurerm_lb" "publicLB" {
 name                = "loadBalancer"
 location            = azurerm_resource_group.rg.location
 resource_group_name = azurerm_resource_group.rg.name

frontend_ip_configuration {
   name                 = "publicIPAddress"
   public_ip_address_id =  azurerm_public_ip.publicIPLB.id
 }
}


resource "azurerm_lb_rule" "publicLBRule" {
  resource_group_name            = azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.publicLB.id
  name                           = "PublicLBRule"
  protocol                       = "Tcp"
  frontend_port                  = 8080
  backend_port                   = 8080
  frontend_ip_configuration_name = "publicIPAddress"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.backendLBPool.id
  probe_id                       = azurerm_lb_probe.HPPublicLB.id
}

resource "azurerm_lb_probe" "HPPublicLB" {
  resource_group_name = azurerm_resource_group.rg.name
  loadbalancer_id     = azurerm_lb.publicLB.id
  name                = "tcp-running-probe"
  port                = 8080
}

resource "azurerm_lb_backend_address_pool" "backendLBPool" {
 resource_group_name = azurerm_resource_group.rg.name
 loadbalancer_id     = azurerm_lb.publicLB.id
 name                = "BackEndAddressPool"
}


#Create Load Balancer - Public Load Balancer
resource "azurerm_lb" "privateLB" {
 name                = "privateLoadBalancer"
 location            = azurerm_resource_group.rg.location
 resource_group_name = azurerm_resource_group.rg.name 


frontend_ip_configuration {
   name                 = "privateIPAddress"
  subnet_id             = azurerm_subnet.privateSubnet.id
  private_ip_address_allocation = "static"
 }
}

resource "azurerm_lb_rule" "privateLBRule" {
  resource_group_name            = azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.privateLB.id
  name                           = "PrivateLBRule"
  protocol                       = "Tcp"
  frontend_port                  = 5432
  backend_port                   = 5432
  frontend_ip_configuration_name = "privateIPAddress"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.privateBackendLBPool.id
  probe_id                       = azurerm_lb_probe.HPPrivateLB.id
}

resource "azurerm_lb_probe" "HPPrivateLB" {
  resource_group_name = azurerm_resource_group.rg.name
  loadbalancer_id     = azurerm_lb.privateLB.id
  name                = "tcp-running-probe"
  port                = 5432
}

resource "azurerm_lb_backend_address_pool" "privateBackendLBPool" {
 resource_group_name = azurerm_resource_group.rg.name
 loadbalancer_id     = azurerm_lb.privateLB.id
 name                = "privateBackendLBPool"
}


#Create nic - Newtwork Interface Card Public
resource "azurerm_network_interface" "nicPublic" {
 count               = 2
 name                = "public-vm${count.index}"
 location                     = azurerm_resource_group.rg.location
 resource_group_name          = azurerm_resource_group.rg.name

 ip_configuration {
   name                          = "nicConfigurationPublic"
   subnet_id                     = azurerm_subnet.publicSubnet.id
   private_ip_address_allocation = "dynamic"
 }
}


#Create nic - Newtwork Interface Card Private
resource "azurerm_network_interface" "nicPrivate" {
 count               = 2
 name                = "private-vm${count.index}"
 location                     = azurerm_resource_group.rg.location
 resource_group_name          = azurerm_resource_group.rg.name

 ip_configuration {
   name                          = "nicConfigurationPrivate"
   subnet_id                     = azurerm_subnet.privateSubnet.id
   private_ip_address_allocation = "dynamic"
 }
}




#network_interface_backend_address_pool_association
resource "azurerm_network_interface_backend_address_pool_association" "example" {
  count                   = 2
  network_interface_id    = "${element(azurerm_network_interface.nicPublic.*.id, count.index)}"
  ip_configuration_name   = "nicConfigurationPublic"
  backend_address_pool_id = azurerm_lb_backend_address_pool.backendLBPool.id
}

#network_interface_backend_address_pool_association private
resource "azurerm_network_interface_backend_address_pool_association" "nicBAPAPrivate" {
  count                   = 2
  network_interface_id    = "${element(azurerm_network_interface.nicPrivate.*.id, count.index)}" 
  ip_configuration_name   = "nicConfigurationPrivate"
  backend_address_pool_id = azurerm_lb_backend_address_pool.privateBackendLBPool.id
}

resource "azurerm_managed_disk" "azureManagedDisk" {
 count                = 2
 name                 = "datadisk_existing_${count.index}"
 location              = azurerm_resource_group.rg.location
 resource_group_name  = azurerm_resource_group.rg.name
 storage_account_type = "Standard_LRS"
 create_option        = "Empty"
 disk_size_gb         = "1023"
}

#Create availability set - Public and Private
resource "azurerm_availability_set" "avsetPublic" {
 name                         = "avsetpublic"
 location                     = azurerm_resource_group.rg.location
 resource_group_name          = azurerm_resource_group.rg.name
 platform_fault_domain_count  = 2
 platform_update_domain_count = 2
 managed                      = true
}

resource "azurerm_availability_set" "avsetPrivate" {
 name                         = "avsetprivate"
 location                     = azurerm_resource_group.rg.location
 resource_group_name          = azurerm_resource_group.rg.name
 platform_fault_domain_count  = 2
 platform_update_domain_count = 2
 managed                      = true
}

#Create network security groups - Public
  resource "azurerm_network_security_group" "publicNsg" {
  name                = "public-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  
  security_rule {
    name                       = "port8080in"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    }

      security_rule {
    name                       = "port8080out"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    }

      security_rule {
     name                       = "rdp-in"
      priority                   = 110
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range    = "3389"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }

      security_rule {
      name                       = "rdp-out"
      priority                   = 110
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range    = "3389"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  }

#subnet network security group association
  resource "azurerm_subnet_network_security_group_association" "publicNsgAssociation" {
  subnet_id                 = azurerm_subnet.publicSubnet.id
  network_security_group_id = azurerm_network_security_group.publicNsg.id
}

# Create network security groups - Private
 resource "azurerm_network_security_group" "privateNsg" {
  name                = "private-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  
  security_rule {
     name                       = "SSH"
     priority                   = 300
     direction                  = "Inbound"
     access                     = "Allow"
     protocol                   = "Tcp"
     source_port_range          = "*"
     destination_port_range     = "22"
     source_address_prefix      = "*"
     destination_address_prefix = "*"
    }

      security_rule {

     name                       = "postgrsqlPort"
     priority                   = 310
     direction                  = "Inbound"
     access                     = "Allow"
     protocol                   = "Tcp"
     source_port_range          = "*"
     destination_port_range     = "5432"
     source_address_prefix      = "*"
     destination_address_prefix = "*"
    }
  }


  resource "azurerm_subnet_network_security_group_association" "privateNsgAssociation" {
  subnet_id                 = azurerm_subnet.privateSubnet.id
  network_security_group_id = azurerm_network_security_group.privateNsg.id
}

#Create virtual machines - Public
resource "azurerm_virtual_machine" "publicVM" {
 count                 = 2
 name                  = "publicVM${count.index}"
 location              = azurerm_resource_group.rg.location
 availability_set_id   = azurerm_availability_set.avsetPublic.id
 resource_group_name   = azurerm_resource_group.rg.name
 network_interface_ids = [element(azurerm_network_interface.nicPublic.*.id, count.index)]
 vm_size               = var.vm_size 



 storage_image_reference {
   publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
 }

 storage_os_disk {
   name              = "myWindowsosdisk${count.index}"
   caching           = "ReadWrite"
   create_option     = "FromImage"
   managed_disk_type = "Standard_LRS"
 }

  os_profile {
   computer_name  = "public-VM${count.index}"
   admin_username = var.admin_username
   admin_password = var.admin_password
 }

  os_profile_windows_config {
   provision_vm_agent = false
 }
}

#Create virtual machines - Private
resource "azurerm_virtual_machine" "privateVM" {
 count                 = 2
 name                  = "privateVM${count.index}"
 location              = azurerm_resource_group.rg.location
 availability_set_id   = azurerm_availability_set.avsetPrivate.id
 resource_group_name   = azurerm_resource_group.rg.name
 network_interface_ids = [element(azurerm_network_interface.nicPrivate.*.id, count.index)]
 vm_size               = "Standard_DS1_v2" 



 storage_image_reference {
   publisher  = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
 }

 storage_os_disk {
   name              = "myLinuxosdisk${count.index}"
   caching           = "ReadWrite"
   create_option     = "FromImage"
   managed_disk_type = "Standard_LRS"
 }

  os_profile {
   computer_name  = "private-VM${count.index}"
   admin_username = "nirh237"
   admin_password = "Azure888801!"
 }

  os_profile_linux_config {
   disable_password_authentication = false
 }
}
