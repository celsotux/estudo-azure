# Lidos pelo terraform/app via terraform_remote_state e pelo pipeline
output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "location" {
  value = azurerm_resource_group.rg.location
}

output "acr_name" {
  value = azurerm_container_registry.acr.name
}

output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}

output "identity_id" {
  value = azurerm_user_assigned_identity.app.id
}

output "environment_id" {
  value = azurerm_container_app_environment.env.id
}
