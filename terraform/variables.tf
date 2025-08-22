# variables.tf
variable "project_name" {
  default = "rfc-ad-project"
}

variable "location" {
  default = "West Europe"
}

variable "resource_group_name" {
  default = "rg-rfc-infra-we"
}

variable "admin_username" {
  default = "rfcadmin"
}

variable "admin_password" {
  default = "Password123!"
}

variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "client_id" {
  description = "Azure Client ID"
  type        = string
}

variable "client_secret" {
  description = "Azure Client Secret"
  type        = string
  sensitive   = true
}

variable "tenant_id" {
  description = "Azure Tenant ID"
  type        = string
}