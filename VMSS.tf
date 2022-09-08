resource "azurerm_resource_group" "rg_name" {
  name     = var.res_name
  location = var.resourcegrouplocation
  tags = {
    "createdby"="vardini" }
}

resource "azurerm_virtual_network" "virtual_net" {
  name                = var.virtual_net
  location            = azurerm_resource_group.rg_name.location
  resource_group_name = azurerm_resource_group.rg_name.name
  address_space       = var.address
  dns_servers         = var.dns_ser_address



  tags = {
    "createdby"="vardini" }
}

resource "azurerm_subnet" "subnet" {
  name                 = var.subnet_name
  resource_group_name  = azurerm_resource_group.rg_name.name
  virtual_network_name = azurerm_virtual_network.virtual_net.name
  address_prefixes     = var.subaddress
  }




resource "azurerm_network_security_group" "nsgrule" {
  name                = "firstnsgrule"
  location            = azurerm_resource_group.rg_name.location
  resource_group_name = azurerm_resource_group.rg_name.name


  security_rule {
    name                       = var.nsgrule1
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "22"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    "createdby"="vardini"
  }
}

resource "azurerm_subnet_network_security_group_association" "example" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsgrule.id
}

# Create public IPs
resource "azurerm_public_ip" "myterraformpublicip" {
  name                = var.mypubip
  location            = azurerm_resource_group.rg_name.location
  resource_group_name = azurerm_resource_group.rg_name.name
  allocation_method   = "Dynamic"
}

# Create network interface
resource "azurerm_network_interface" "myterraformnic" {
  name                = var.mynic
  location            = azurerm_resource_group.rg_name.location
  resource_group_name = azurerm_resource_group.rg_name.name

  ip_configuration {
    name                          = "myNicConfiguration"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.myterraformpublicip.id
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.myterraformnic.id
  network_security_group_id = azurerm_network_security_group.nsgrule.id
}

# Create (and display) an SSH key
resource "tls_private_key" "first_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "myterra_vm" {
  name                  = var.myvm
  location              = azurerm_resource_group.rg_name.location
  resource_group_name   = azurerm_resource_group.rg_name.name
  network_interface_ids = [azurerm_network_interface.myterraformnic.id]
  size                  = "Standard_B1s"

  os_disk {
    name                 = "myOsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

   computer_name                  = "myterravm"
  admin_username                  = "azureuser"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.first_ssh.public_key_openssh
  }
}

#create load balancer
resource "azurerm_public_ip" "forloadbal" {
  name                = var.PublicIPForLB
  location            = azurerm_resource_group.rg_name.location
  resource_group_name = azurerm_resource_group.rg_name.name
  allocation_method   = "Static"
  sku = "Standard"
}

resource "azurerm_lb" "load_bal01" {
  name                = var.loadbalancer
  location            = azurerm_resource_group.rg_name.location
  resource_group_name = azurerm_resource_group.rg_name.name
  sku = "Standard"

  frontend_ip_configuration {
    name                 = var.fronendip
    public_ip_address_id = azurerm_public_ip.forloadbal.id
  }
}

resource "azurerm_lb_backend_address_pool" "backendpool" {
  loadbalancer_id = azurerm_lb.load_bal01.id
  name            = var.backend_pool_01
}

resource "azurerm_lb_backend_address_pool_address" "example" {
  name                    = var.backend_pool_01
  backend_address_pool_id = azurerm_lb_backend_address_pool.backendpool.id
  virtual_network_id      = azurerm_virtual_network.virtual_net.id
  ip_address = azurerm_linux_virtual_machine.myterra_vm.private_ip_address
}
/*
resource "azurerm_network_interface_backend_address_pool_association" "backpool_nic" {
  network_interface_id    = azurerm_network_interface.myterraformnic.id
  ip_configuration_name   = "myNicConfiguration"
  backend_address_pool_id = azurerm_lb_backend_address_pool.backendpool.id
}

*/
resource "azurerm_lb_rule" "lbalancerule01" {
  loadbalancer_id                = azurerm_lb.load_bal01.id
  name                           = var.lbrule01
  protocol                       = "Tcp"
  frontend_port                  = 22
  backend_port                   = 22
  frontend_ip_configuration_name = var.fronendip
}

resource "azurerm_lb_probe" "example" {
  loadbalancer_id = azurerm_lb.load_bal01.id
  name            = "ssh-running-probe"
  port            = 22
}

#create virtual machine scale set
resource "azurerm_virtual_machine_scale_set" "firstvmss" {
  name                = var.firstvmss
  location            = azurerm_resource_group.rg_name.location
  resource_group_name = azurerm_resource_group.rg_name.name


  # automatic rolling upgrade
  #automatic_os_upgrade = true
  upgrade_policy_mode  = "Manual"
/*
  rolling_upgrade_policy {
    max_batch_instance_percent              = 20
    max_unhealthy_instance_percent          = 20
    max_unhealthy_upgraded_instance_percent = 5
    pause_time_between_batches              = "PT0S"
  }
*/
   #health_probe_id = azurerm_lb_probe.example.id  

sku {
    name     = "Standard_B1s"
    tier     = "Standard"
    capacity = 2
  }

    storage_profile_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  storage_profile_os_disk {
    #name              = "myvmssosdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

    storage_profile_data_disk {
    lun           = 0
    caching       = "ReadWrite"
    create_option = "Empty"
    disk_size_gb  = 10
  }

  os_profile {
    computer_name_prefix = "testvm"
    admin_username       = "azureuser"
  }

  os_profile_linux_config {
    disable_password_authentication = true

  ssh_keys {
      path     = "/home/azureuser/.ssh/authorized_keys"
      key_data = file("~/.ssh/id_rsa.pub")
    }
  }
  network_profile {
    name    = "vmssnetworkprofile"
    primary = true

    ip_configuration {
      name                                   = "vmssIPConfiguration"
      primary                                = true
      subnet_id                              = azurerm_subnet.subnet.id
    }

  }
}


