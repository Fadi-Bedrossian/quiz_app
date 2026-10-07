variable "prefix" {
  type = string
}

variable "suffix" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "secrets_officer_principal_id" {
  type = string
}

variable "postgres_admin_password" {
  type      = string
  sensitive = true
}

variable "appinsights_connection_string" {
  type      = string
  sensitive = true
}
