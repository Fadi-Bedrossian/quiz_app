variable "subscription_id" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "location" {
  type    = string
  default = "northeurope"
}

variable "resource_group_name" {
  type    = string
  default = "sg-quiz-rg"
}

variable "prefix" {
  type    = string
  default = "sg"
}

variable "github_owner" {
  type    = string
  default = "Fadi-Bedrossian"
}

variable "github_repo" {
  type    = string
  default = "quiz_app"
}

variable "infra_client_id" {
  type        = string
  description = "Client ID of bootstrap GitHub Actions infrastructure identity"
}

variable "node_vm_size" {
  type        = string
  description = "AKS system node VM size selected for the current subscription quota"
  default     = "Standard_DC2as_v6"
}
