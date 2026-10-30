# Aplicação no Azure Container Apps (mesmo papel do infra/app.bicep)

# Lê as saídas do terraform/base (ACR, identidade, Environment) direto do estado dele
data "terraform_remote_state" "base" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.tfstate_resource_group
    storage_account_name = var.tfstate_storage_account
    container_name       = var.tfstate_container
    key                  = "base.tfstate"
  }
}

locals {
  base = data.terraform_remote_state.base.outputs
}

resource "azurerm_container_app" "app" {
  name                         = var.app_name
  resource_group_name          = local.base.resource_group_name
  container_app_environment_id = local.base.environment_id
  workload_profile_name        = "Consumption"
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [local.base.identity_id]
  }

  registry {
    server   = local.base.acr_login_server
    identity = local.base.identity_id
  }

  ingress {
    external_enabled           = true
    target_port                = var.container_port
    transport                  = "auto"
    allow_insecure_connections = false

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = var.app_name
      image  = var.image
      cpu    = 0.25
      memory = "0.5Gi"

      liveness_probe {
        transport        = "HTTP"
        port             = var.container_port
        path             = "/healthcheck"
        interval_seconds = 30
      }

      readiness_probe {
        transport        = "HTTP"
        port             = var.container_port
        path             = "/healthcheck"
        interval_seconds = 10
      }
    }

    http_scale_rule {
      name                = "http-scale"
      concurrent_requests = "50"
    }
  }
}
