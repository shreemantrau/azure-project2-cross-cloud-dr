/*
We need either admin_enabled = true or RBAC to push the docker image in ACR 
once admin_enabled = true following happens

1) Azure will automatically create username and password
2) We will need this to push docker image to ACR
3) Then App Service will need them to get. the image from ACR to build the underlying infra and then run the required code (app.py in our case)

Chose admin_enabled = true first to understand the credential flow end-to-end.
RBAC (Managed Identity + AcrPull) is the more secure alternative — same pattern
as Key Vault — worth revisiting later. Create an Identity where type = systemAssigned and then grant the app.web a role in ACR
*/

resource "azurerm_container_registry" "main" {
  name = "acrproj2dr"
  resource_group_name = azurerm_resource_group.main.name
  location = azurerm_resource_group.main.location
  sku = "Basic"
  admin_enabled = true 
}

resource "azurerm_role_assignment" "acr_pull_app" {
  scope = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id = azurerm_linux_web_app.app.identity[0].principal_id
}

resource "azurerm_role_assignment" "acr_pull_web" {
  scope = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id = azurerm_linux_web_app.web.identity[0].principal_id
}