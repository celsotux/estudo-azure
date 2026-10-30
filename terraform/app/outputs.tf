output "url" {
  value = "https://${azurerm_container_app.app.ingress[0].fqdn}"
}
