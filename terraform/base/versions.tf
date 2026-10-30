terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Estado guardado numa Storage Account; os valores são passados no "terraform init" pelo pipeline
  backend "azurerm" {}
}

provider "azurerm" {
  features {}

  # Os providers usados pelo projeto já foram registrados na assinatura (ver docs/passo-a-passo.md)
  resource_provider_registrations = "none"
}
