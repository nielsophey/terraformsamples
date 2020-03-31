## Deploy your first VM to Azure
## based on an Ubunto Image

## Define th provider
provider "azurerm" {
  version = "~>2.2.0"
  features {}
}

## Define output variables
output "public_ip" {
   value       = azurerm_public_ip.myFirstTerraform.ip_address
   description = "This is the asigned public ip to our VM"
}

## Define the deployment
resource "azurerm_resource_group" "myFirstTerraform" {
  name     = "myFirstTerraform-RG"
  location = "West Europe"
}

resource "azurerm_virtual_network" "myFirstTerraform" {
  name                = "myFirstTerraform-vNet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.myFirstTerraform.location
  resource_group_name = azurerm_resource_group.myFirstTerraform.name
}

resource "azurerm_subnet" "myFirstTerraform" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.myFirstTerraform.name
  virtual_network_name = azurerm_virtual_network.myFirstTerraform.name
  address_prefix       = "10.0.2.0/24"
}

resource "azurerm_public_ip" "myFirstTerraform" {
  name                = "myFirstTerraform-pip"
  location            = azurerm_resource_group.myFirstTerraform.location
  resource_group_name = azurerm_resource_group.myFirstTerraform.name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "myFirstTerraform" {
  name                = "myFirstTerraform-nic"
  location            = azurerm_resource_group.myFirstTerraform.location
  resource_group_name = azurerm_resource_group.myFirstTerraform.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.myFirstTerraform.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.myFirstTerraform.id
  }
}

resource "azurerm_network_security_group" "myFirstTerraform" {
    name                = "myFirstTerraform"
    location            = azurerm_resource_group.myFirstTerraform.location
    resource_group_name = azurerm_resource_group.myFirstTerraform.name
    
    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
     }
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

resource "azurerm_network_interface_security_group_association" "myFirstTerraform" {
    network_interface_id      = azurerm_network_interface.myFirstTerraform.id
    network_security_group_id = azurerm_network_security_group.myFirstTerraform.id
}

resource "azurerm_linux_virtual_machine" "myFirstTerraform" {
  name                = "myFirstTerraform-vm"
  resource_group_name = azurerm_resource_group.myFirstTerraform.name
  location            = azurerm_resource_group.myFirstTerraform.location
  size                = "Standard_B2s"
  computer_name = "myFirstLinuxVM"
  admin_username = "adminuser"
  admin_password = "Password1234!"
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.myFirstTerraform.id,
  ]
  # custom_data = "${base64encode(file("webserv.sh"))}"

    os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_extension" "myFirstTerraform" {
  name = "myFirstTerraform-Script"
  virtual_machine_id = azurerm_linux_virtual_machine.myFirstTerraform.id
  publisher = "Microsoft.Azure.Extensions"
  type = "CustomScript"
  type_handler_version ="2.0"

  settings = <<SETTINGS
    {
      "commandToExecute" : "apt-get -y update && apt-get install -y apache2" 
    }
    SETTINGS
 }
