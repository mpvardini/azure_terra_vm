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





