
resource "azurerm_service_plan" "main" {
  name = "asp-proj2dr"
  resource_group_name = azurerm_resource_group.main.name
  location = azurerm_resource_group.main.location
  sku_name = "B1"
  os_type = "Linux"
}

resource "azurerm_linux_web_app" "web" {
  name = "app-proj2dr-web"
  service_plan_id = azurerm_service_plan.main.id
  resource_group_name = azurerm_resource_group.main.name
  location = azurerm_resource_group.main.location
  
  //below we are letting the app running in web_app.web know that web_app.app exists here
  //this way it can communicate with it. Similar to SQL link in app.app
  app_settings = {
    "APP_TIER_URL" = "https://${azurerm_linux_web_app.app.default_hostname}"
  }

  identity {
    type = "SystemAssigned"
  }

  site_config {
    container_registry_use_managed_identity = true
    application_stack {
      docker_image_name = "app-proj2dr-web:latest"
      docker_registry_url = "https://acrproj2dr.azurecr.io" //name of the the container that we have in container.tf

    }
  }

}

resource "azurerm_linux_web_app" "app" {
  name = "app-proj2dr-app"
  service_plan_id = azurerm_service_plan.main.id
  location = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  //this moves the outbound traffic of app.app through the subnet belwow ... 
  //outbound traffic will now reach SQL and KeyVault, since both of them have Private Endpoints
  //In order to communicate the traffic must originate from the same VNET
  
  virtual_network_subnet_id = azurerm_subnet.app.id // inline version or the commented block below
  
  identity {
    type = "SystemAssigned"
  }
  
  app_settings = {
    "KEY_VAULT_URL" = azurerm_key_vault.main.vault_uri
    "SQL_SERVER" = azurerm_mssql_server.main.fully_qualified_domain_name
    "SQL_DATABASE" = azurerm_mssql_database.main.name
    "SQL_USER" = azurerm_mssql_server.main.administrator_login
    "SQL_PASSWORD" = "@Microsoft.KeyVault(SecretUri=https://kv-proj2-dr.vault.azure.net/secrets/sql-admin-password/18509100ac4640378115b8874ee71e75)"
  }

  site_config {
    vnet_route_all_enabled = true
    application_stack {
      docker_image_name = "app-proj2dr-app:latest"
      docker_registry_url = "https://acrproj2dr.azurecr.io" //name of the the container that we have in container.tf
    }
  }

}
// use the inline verion above or the commented block below (Project 1 has the block below, project we go inline)
/*
resource "azurerm_app_service_virtual_network_swift_connection" "vnet_integration" {
  subnet_id = azurerm_subnet.app.id
  app_service_id = azurerm_linux_web_app.app.id
}*/