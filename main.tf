
resource "azurerm_resource_group" "example" {
  name     = "test-resourcegroup-${var.environment}"
  location = var.location
}