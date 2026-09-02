#  Read-only lookup of the currently authenticated identity ... tenant_id is safe to reuse anywhere; 
#  object_id is NOT — differs between local and CI
data "azurerm_client_config" "current" {
  
} 

resource "azurerm_key_vault" "main" {
  name = "kv-proj2-dr"
  location = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id = data.azurerm_client_config.current.tenant_id
  sku_name = "standard"
  public_network_access_enabled = true
  enable_rbac_authorization = true
}

resource "azurerm_private_endpoint" "keyvault" {
  name = "pe-keyvault-proj2dr"
  location = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id = azurerm_subnet.keyvault.id
  private_service_connection {
    name = "psc-keyvault"
    is_manual_connection = false
    private_connection_resource_id = azurerm_key_vault.main.id
    subresource_names = ["vault"]
  }
}

resource "azurerm_private_dns_zone" "keyvault_dns" {
  name = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "keyvault_dns_link" {
  name = "keyvault-dns-link"
  resource_group_name = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.keyvault_dns.name
  virtual_network_id = azurerm_virtual_network.main.id
}

resource "azurerm_private_dns_a_record" "keyvault" {
  name = "kv-proj2-dr"
  ttl = 300
  resource_group_name = azurerm_resource_group.main.name
  records = [azurerm_private_endpoint.keyvault.private_service_connection[0].private_ip_address]
  zone_name = azurerm_private_dns_zone.keyvault_dns.name
}

resource "azurerm_role_assignment" "rbac-app" {
  principal_id = azurerm_linux_web_app.app.identity[0].principal_id //using the identity from the identity block of linux_web_app.app
  scope = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
}