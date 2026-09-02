resource "azurerm_mssql_server" "main" {
    name = "sql-proj2dr"
    resource_group_name = azurerm_resource_group.main.name
    location = azurerm_resource_group.main.location
    version = "12.0"
    administrator_login = "sqladmin"
    administrator_login_password = var.sql_password
    public_network_access_enabled = true
}

resource "azurerm_mssql_database" "main" {
  name = "proj2dr-db"
  server_id = azurerm_mssql_server.main.id
}

resource "azurerm_private_dns_zone" "sql_dns" {
  name = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_private_endpoint" "sql" {
  name = "pe-sql-proj2dr"
  subnet_id = azurerm_subnet.data.id
  location = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  private_service_connection {
    name = "psc-sql"
    private_connection_resource_id = azurerm_mssql_server.main.id
    subresource_names = ["sqlServer"]
    is_manual_connection = false
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql_dns_link" {
  name = "sql-dns-link"
  resource_group_name = azurerm_resource_group.main.name
  virtual_network_id = azurerm_virtual_network.main.id
  private_dns_zone_name = azurerm_private_dns_zone.sql_dns.name
}

resource "azurerm_private_dns_a_record" "sql" {
  name = "sql-proj2dr"
  resource_group_name = azurerm_resource_group.main.name
  zone_name = azurerm_private_dns_zone.sql_dns.name
  ttl = 300
  records = [azurerm_private_endpoint.sql.private_service_connection[0].private_ip_address]
}