resource "azurerm_resource_group" "main" {
  name = "rg-project2-dr"
  location = "westus2"
}

resource "azurerm_virtual_network" "main" {
  name = "proj2dr-vnet"
  location = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "web" {
  name = "snet-web"
  resource_group_name = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "app" {
  name = "snet-app"
  resource_group_name = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes = ["10.0.2.0/24"]

  delegation {
    name = "app-service-delegation"
    service_delegation {
      name = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet" "data" {
  name = "snet-data"
  resource_group_name = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes = ["10.0.3.0/24"]
}

resource "azurerm_subnet" "keyvault" {
  name = "snet-keyvault"
  resource_group_name = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes = ["10.0.4.0/24"]
}

#------------------NSG-----------------
resource "azurerm_network_security_group" "web" {
  location = azurerm_resource_group.main.location
  name = "nsg-web"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_network_security_group" "data" {
  location = azurerm_resource_group.main.location
  name = "nsg-data"
  resource_group_name = azurerm_resource_group.main.name
}
resource "azurerm_network_security_group" "app" {
  location = azurerm_resource_group.main.location
  name = "nsg-app"
  resource_group_name = azurerm_resource_group.main.name
}
resource "azurerm_network_security_group" "keyvault" {
  location = azurerm_resource_group.main.location
  name = "nsg-keyvault"
  resource_group_name = azurerm_resource_group.main.name
}
#---------------NSG Association-----------------

resource "azurerm_subnet_network_security_group_association" "web" {
  network_security_group_id = azurerm_network_security_group.web.id
  subnet_id = azurerm_subnet.web.id
}

resource "azurerm_subnet_network_security_group_association" "app" {
  network_security_group_id = azurerm_network_security_group.app.id
  subnet_id = azurerm_subnet.app.id
}

resource "azurerm_subnet_network_security_group_association" "data" {
  network_security_group_id = azurerm_network_security_group.data.id
  subnet_id = azurerm_subnet.data.id
}

resource "azurerm_subnet_network_security_group_association" "keyvault" {
  network_security_group_id = azurerm_network_security_group.keyvault.id
  subnet_id = azurerm_subnet.keyvault.id
}

#----------------------NSG Rules------------------

resource "azurerm_network_security_rule" "web_inbound" {
  name = "allow-https-inbound"
  priority = 100
  direction = "Inbound"
  access = "Allow"
  protocol = "Tcp"
  source_port_range = "*"
  destination_port_range = "443"
  source_address_prefix  = "Internet"
  destination_address_prefix  = "*"
  resource_group_name = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.web.name
}

resource "azurerm_network_security_rule" "app_inbound" {
  name = "allow-web-to-app"
  priority = 100
  direction = "Inbound"
  access = "Allow"
  protocol = "Tcp"
  source_port_range = "*"
  destination_port_range = "5000" //flash coomunicates at 5000
  source_address_prefix = "10.0.1.0/24"
  destination_address_prefix = "*"
  resource_group_name = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.app.name
}

resource "azurerm_network_security_rule" "data_inbound" {
  name = "allow-app-to-data"
  priority = 100
  direction = "Inbound"
  protocol = "Tcp"
  access = "Allow"
  source_port_range = "*"
  destination_port_range = "1433"
  source_address_prefix = "10.0.2.0/24"
  destination_address_prefix = "*"
  resource_group_name = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.data.name
}

resource "azurerm_network_security_rule" "keyvault_inbound" {
  name = "allow-app-to-keyvault"
  priority = 100
  direction = "Inbound"
  protocol = "Tcp"
  access = "Allow"
  source_port_range = "*"
  destination_port_range = "443"
  source_address_prefix = "10.0.2.0/24"
  destination_address_prefix = "*"
  resource_group_name = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.keyvault.name
}