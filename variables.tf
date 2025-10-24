variable "location" {
  type        = string
  description = "(Optional) Azure region to use. Defaults to East US."
  default     = "eastus"
}

variable "environment" {
  type        = string
  description = "Deployment environment (dev, test, prod)"
  default     = "dev"
}
