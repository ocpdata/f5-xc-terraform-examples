variable "tf_cloud_organization" {
  type = string
  description = "TF cloud org (Value set in TF cloud)"
}

variable "azure_infra_workspace" {
  type        = string
  description = "TFC workspace name for Azure Infra (used to read remote state)"
}

variable "azure_subscription_id" {
  type    = string
}

variable "azure_subscription_tenant_id" {
  type    = string
}

variable "azure_service_principal_appid" {
  type    = string
}

variable "azure_service_principal_password" {
  type    = string
}

variable "use_new_vnet" {
  type = bool
  default = false
}