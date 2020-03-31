## Lets start with a VMSS in Azure
provider "azurerm" {
    version = "~>2.2.0"
    features {}
}

### Random FQDN String
resource "random_string" "fqdn" {
 length  = 6
 special = false
 upper   = false
 number  = false
}

### Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "rg-vmssssample-test"
  location = "East US"
  tags = {
      App = "VMSS"
      Source = "Terraform"
  }
}

### Network
resource "azurerm_virtual_network" "vNet" {
  name                = "vnet-shared-eastus-001"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.0.0.0/16"]
  tags = azurerm_resource_group.rg.tags
}

### Subnet
resource "azurerm_subnet" "sNet" {
  name                 = "snet-shared-vmsssample-001"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vNet.name
  address_prefix       = "10.0.2.0/24"
}

### Public IP

resource "azurerm_public_ip" "vmss-pip" {
  name                         = "pip-vmsssample-test-eastus-001"
  location                     = azurerm_resource_group.rg.location
  resource_group_name          = azurerm_resource_group.rg.name
  allocation_method            = "Static"
  domain_name_label            = random_string.fqdn.result

  tags = azurerm_resource_group.rg.tags
}

### Loadbalancer definition
resource "azurerm_lb" "vmsssample" {
 name                = "lb-vmsssample-test-001"
 location            = azurerm_resource_group.rg.location
 resource_group_name = azurerm_resource_group.rg.name

 frontend_ip_configuration {
   name                 = "ipconf-PublicIPAddress-test"
   public_ip_address_id = azurerm_public_ip.vmss-pip.id
 }

  tags = azurerm_resource_group.rg.tags
}

### Define the backend pool
resource "azurerm_lb_backend_address_pool" "vmsssample" {
 resource_group_name = azurerm_resource_group.rg.name
 loadbalancer_id     = azurerm_lb.vmsssample.id
 name                = "ipconf-BackEndAddressPool-test"
}

### Define the lb probes
resource "azurerm_lb_probe" "vmsssample" {
 resource_group_name = azurerm_resource_group.rg.name
 loadbalancer_id     = azurerm_lb.vmsssample.id
 name                = "http-running-probe"
 port                = 80
}

### Define the lb rule
resource "azurerm_lb_rule" "vmsssample" {
   resource_group_name            = azurerm_resource_group.rg.name
   loadbalancer_id                = azurerm_lb.vmsssample.id
   name                           = "http"
   protocol                       = "Tcp"
   frontend_port                  = 80
   backend_port                   = 80
   backend_address_pool_id        = azurerm_lb_backend_address_pool.vmsssample.id
   frontend_ip_configuration_name = "ipconf-PublicIPAddress-test"
   probe_id                       = azurerm_lb_probe.vmsssample.id
}

### Define the NSG
resource "azurerm_network_security_group" "vmsssample" {
    name                = "nsg-weballow-001"
    location            = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    
     security_rule {
        name                       = "WebServer"
        priority                   = 1002
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "80"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
     }
}

### The VM Scale Set (VMSS)
resource "azurerm_linux_virtual_machine_scale_set" "vmsssample" {
  name                = "vmss-vmsssample-test-001"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Standard_B2s"
  instances           = 1
  admin_username      = "adminuser"
  admin_password      = "Password1234!"
  disable_password_authentication = false
  tags = azurerm_resource_group.rg.tags

#### define the os image
 source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

#### define the os disk
  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

#### Define Network
  network_interface {
      name    = "nic-01-vmsssample-test-001"
      primary = true

    ip_configuration {
        name      = "ipconf-vmssample-test"
        primary   = true
        subnet_id = azurerm_subnet.sNet.id
        load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.vmsssample.id]
    }
    network_security_group_id = azurerm_network_security_group.vmsssample.id

  }
}
### Add the Webserver to the VMSS
resource "azurerm_virtual_machine_scale_set_extension" "vmsssampleextension" {
  name                         = "ext-vmsssample-test"
  virtual_machine_scale_set_id = azurerm_linux_virtual_machine_scale_set.vmsssample.id
  publisher                    = "Microsoft.Azure.Extensions"
  type                         = "CustomScript"
  type_handler_version         = "2.0"
  auto_upgrade_minor_version   = true
  force_update_tag             = true
  
  settings = jsonencode({
      "commandToExecute" : "apt-get -y update && apt-get install -y apache2" 
    })
}
