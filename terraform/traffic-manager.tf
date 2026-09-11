// Traffic Manager profile - the routing policy itself. Priority mode = try endpoint 1 first, fall back to next on failure
resource "azurerm_traffic_manager_profile" "main" {
 name = "proj2dr-tm"
 resource_group_name = azurerm_resource_group.main.name
 traffic_routing_method = "Priority"

 dns_config {
   relative_name = "proj2dr-failover"
   ttl = 30
 }

 monitor_config {
   protocol = "HTTP"
   port = 80
   path = "/"
 }
}

// Azure endpoint - the primary. Native Azure resource, referenced directly by its resource ID
resource "azurerm_traffic_manager_azure_endpoint" "azure_primary" {
  name = "azure-primary"
  profile_id = azurerm_traffic_manager_profile.main.id
  target_resource_id = azurerm_linux_web_app.web.id
  priority = 1
}

// AWS endpoint - the failover. "External" since AWS isn't a native Azure resource, referenced by raw IP instead
// KNOWN LIMITATION: hardcoded IP will go stale on next ECS task restart - would need an ALB (Application Load Balancer just like Azure load Balancer) for a stable endpoint in production
resource "azurerm_traffic_manager_external_endpoint" "aws_failover" {
  name = "aws-failover"
  profile_id = azurerm_traffic_manager_profile.main.id
  target = "52.27.126.185.nip.io"
  priority = 2
}