# --- Infrastructure values passed from azure-infra and aks-cluster jobs --- #

variable "project_prefix" {
  type        = string
  description = "Project prefix (from azure-infra output)"
}

variable "build_suffix" {
  type        = string
  description = "Random build suffix (from azure-infra output)"
}

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
  description = "Azure VNet name (from azure-infra output)"
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

variable "vnet_id" {
  type        = string
  description = "Azure VNet ID (from azure-infra output)"
  default     = ""
}

variable "kubeconfig" {
  type        = string
  description = "AKS kubeconfig (from aks-cluster output) — used for XC service discovery"
  sensitive   = true
  default     = ""
}

# --- Azure credentials (GitHub Secrets via TF_VAR_*) --- #

variable "azure_subscription_id" {
  description = "Azure Subscription ID"
  type        = string
  sensitive   = true
  default     = null
}

variable "azure_subscription_tenant_id" {
  description = "Azure Tenant ID"
  type        = string
  sensitive   = true
  default     = null
}

variable "azure_service_principal_appid" {
  description = "Azure Client ID"
  type        = string
  sensitive   = true
  default     = null
}

variable "azure_service_principal_password" {
  description = "Azure Client Secret"
  type        = string
  sensitive   = true
  default     = null
}

variable "azure_xc_machine_type" {
  type    = string
  default = "Standard_D4s_v3"
}

# --- XC credentials --- #

variable "ssh_key" {
  type        = string
  description = "SSH public key for XC CE node"
}

variable "api_url" {
  type        = string
  description = "F5 XC tenant API URL"
}

variable "xc_tenant" {
  type        = string
  description = "F5 XC tenant name"
}

variable "xc_namespace" {
  type        = string
  description = "XC namespace where objects will be created"
}

# --- XC Load Balancer --- #

variable "app_domain" {
  type        = string
  description = "FQDN for the application load balancer"
}

variable "http_only" {
  type        = string
  description = "Use HTTP listener (true) or HTTPS auto-cert (false)"
  default     = "false"
}

variable "xc_delegation" {
  type        = string
  description = "F5 XC domain delegation for automatic DNS management"
  default     = "false"
}

variable "advertise_sites" {
  type        = string
  description = "Advertise LB on specific CE sites (true) or public VIP (false)"
  default     = "false"
}

variable "site_name" {
  type        = string
  description = "CE site name (defaults to project_prefix when empty)"
  default     = ""
}

variable "gke_site_name" {
  type        = string
  description = "GKE site name (unused in Azure deployments)"
  default     = ""
}

variable "ip_address_on_site_pool" {
  type        = string
  description = "Use private IP on site for origin pool"
  default     = "false"
}

variable "user_site" {
  type        = string
  description = "Whether CE site is owned by the user (vs. ves-io)"
  default     = "false"
}

# --- K8s backend --- #

variable "k8s_pool" {
  type        = string
  description = "Use Kubernetes service as origin pool backend"
  default     = "false"
}

variable "serviceName" {
  type        = string
  description = "K8s service name (e.g. frontend.default)"
  default     = ""
}

variable "serviceport" {
  type        = string
  description = "K8s service port"
  default     = ""
}

# --- XC WAF --- #

variable "xc_waf_blocking" {
  type        = string
  description = "Enable WAF blocking mode (true) or monitoring (false)"
  default     = "false"
}

variable "xc_data_guard" {
  type        = string
  description = "Enable XC Data Guard"
  default     = "false"
}

# --- XC AI/ML (App Type, MUD) --- #

variable "xc_app_type" {
  type        = list(any)
  description = "App type labels for shared AI/ML features"
  default     = null
}

variable "xc_multi_lb" {
  type        = string
  description = "AI/ML configured via app type label on LB"
  default     = "false"
}

variable "xc_mud" {
  type        = string
  description = "Enable Malicious User Detection"
  default     = "false"
}

# --- XC API Protection & Discovery --- #

variable "xc_api_disc" {
  type    = string
  default = "false"
}

variable "xc_api_pro" {
  type    = string
  default = "false"
}

variable "xc_api_spec" {
  type    = list(any)
  default = null
}

variable "xc_api_val" {
  type    = string
  default = "false"
}

variable "xc_api_val_all" {
  type    = string
  default = "false"
}

variable "xc_api_val_properties" {
  type    = list(string)
  default = ["PROPERTY_QUERY_PARAMETERS", "PROPERTY_PATH_PARAMETERS", "PROPERTY_CONTENT_TYPE", "PROPERTY_COOKIE_PARAMETERS", "PROPERTY_HTTP_HEADERS", "PROPERTY_HTTP_BODY"]
}

variable "xc_resp_val_properties" {
  type    = list(string)
  default = ["PROPERTY_HTTP_HEADERS", "PROPERTY_CONTENT_TYPE", "PROPERTY_HTTP_BODY", "PROPERTY_RESPONSE_CODE"]
}

variable "xc_api_val_active" {
  type    = string
  default = "false"
}

variable "xc_resp_val_active" {
  type    = string
  default = "false"
}

variable "enforcement_block" {
  type    = string
  default = "false"
}

variable "enforcement_report" {
  type    = string
  default = "false"
}

variable "fall_through_mode_allow" {
  type    = string
  default = "false"
}

variable "xc_api_val_custom" {
  type    = string
  default = "false"
}

# --- JWT Validation --- #

variable "xc_jwt_val" {
  type    = string
  default = "false"
}

variable "jwt_val_block" {
  type    = string
  default = "false"
}

variable "jwt_val_report" {
  type    = string
  default = "false"
}

variable "jwks" {
  type    = string
  default = "app_domain"
}

variable "iss_claim" {
  type    = string
  default = "false"
}

variable "aud_claim" {
  type    = list(string)
  default = [""]
}

variable "val_period_enable" {
  type    = string
  default = "false"
}

# --- XC Bot & DDoS --- #

variable "xc_bot_def" {
  type    = string
  default = "false"
}

variable "xc_ddos_pro" {
  type    = string
  default = "false"
}

# --- XC CE Site --- #

variable "az_ce_site" {
  type        = string
  description = "Deploy Azure CE site for AppConnect"
  default     = "false"
}

variable "xc_service_discovery" {
  type        = string
  description = "Enable XC service discovery for K8s backend"
  default     = "false"
}

# --- vK8s (disabled for this workflow) --- #

variable "vk8s" {
  description = "Use XC vK8s as infrastructure (set false for AKS deployments)"
  type        = bool
  default     = false
}
