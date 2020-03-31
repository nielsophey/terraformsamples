## Lets start with a VMSS in Azure
provider "azurerm" {
    version = "~>2.3.0"
    features {}
}

### Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "rg-appservice-test"
  location = "West Europe"
  tags = {
      App = "appservice"
      Source = "Terraform"
  }
}

### App Service plan
resource "azurerm_app_service_plan" "appservice" {
  name                = "azapp-plan-eastus-001"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  sku {
    tier = "Standard"
    size = "S1"
  }
}

## The App Service 
resource "azurerm_app_service" "appservice" {
  name                = "azapp-appservice-test-001"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  app_service_plan_id = azurerm_app_service_plan.appservice.id
}

## Deploy the Deployment option by ARM Template
resource "azurerm_template_deployment" "appservice" {
    name                    = "arm-appservice-template"
    resource_group_name     = azurerm_resource_group.rg.name

    template_body = file("appservice.json")

    parameters = {
        "siteName" = azurerm_app_service.appservice.name
        "location" = azurerm_resource_group.rg.location
    }

    deployment_mode = "Incremental"
  
}
