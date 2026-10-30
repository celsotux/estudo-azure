# Infraestrutura base: registro de imagens, identidade, logs e Container Apps Environment
# (mesmo papel do infra/main.bicep)

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# Nome do ACR precisa ser único no mundo todo, só letras e números
resource "random_string" "acr_suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_container_registry" "acr" {
  name                = "acr${var.prefix}${random_string.acr_suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = false
}

# Identidade usada pelo app para baixar a imagem do ACR sem senha
resource "azurerm_user_assigned_identity" "app" {
  name                = "id-${var.prefix}-app"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_log_analytics_workspace" "logs" {
  name                = "log-${var.prefix}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# Sem VNet própria, como na versão Bicep: criação e remoção mais rápidas
resource "azurerm_container_app_environment" "env" {
  name                       = "cae-${var.prefix}"
  resource_group_name        = azurerm_resource_group.rg.name
  location                   = azurerm_resource_group.rg.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.logs.id

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }
}
