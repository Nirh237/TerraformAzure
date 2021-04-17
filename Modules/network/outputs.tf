output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "azure_location" {
  value = azurerm_resource_group.rg.location
}