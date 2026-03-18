# --- Infra outputs passed from azure-infra job via GitHub Actions outputs --- #

variable "azure_region" {
  type        = string
  description = "Azure region (from azure-infra output)"
}

variable "resource_group_name" {
  type        = string
  description = "Azure Resource Group name (from azure-infra output)"
}

variable "vnet_name" {
  type        = string
  description = "Azure Virtual Network name (from azure-infra output)"
}

variable "subnet_name" {
  type        = string
  description = "Azure Subnet name (from azure-infra output)"
}

variable "subnet_id" {
  type        = string
  description = "Azure Subnet ID (from azure-infra output)"
  default     = ""
}

variable "project_prefix" {
  type        = string
  description = "Project prefix (from azure-infra output)"
}

variable "build_suffix" {
  type        = string
  description = "Random build suffix (from azure-infra output)"
}

variable "vnet_id" {
  type        = string
  description = "Azure Virtual Network ID (from azure-infra output)"
  default     = ""
}

# --- Azure credentials (GitHub Secrets via TF_VAR_*) --- #

variable "azure_subscription_id" {
  type      = string
  sensitive = true
}

variable "azure_subscription_tenant_id" {
  type      = string
  sensitive = true
}

variable "azure_service_principal_appid" {
  type      = string
  sensitive = true
}

variable "azure_service_principal_password" {
  type      = string
  sensitive = true
}

# --- AKS options --- #

variable "use_new_vnet" {
  type    = bool
  default = false
}
