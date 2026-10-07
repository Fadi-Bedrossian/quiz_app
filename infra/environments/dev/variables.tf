variable "subscription_id" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "infra_client_id" {
  type = string
}

variable "resource_group_name" {
  type    = string
  default = "sg-quiz-rg"
}

variable "location" {
  type    = string
  default = "northeurope"
}

variable "prefix" {
  type    = string
  default = "sg"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "github_owner" {
  type    = string
  default = "Fadi-Bedrossian"
}

variable "github_repo" {
  type    = string
  default = "quiz_app"
}

variable "tfstate_resource_group" {
  type    = string
  default = "sg-tfstate-rg"
}

variable "tfstate_storage_account" {
  type = string
}

variable "tfstate_container" {
  type    = string
  default = "tfstate"
}
