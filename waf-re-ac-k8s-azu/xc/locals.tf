locals {
  # Infra values received directly as variables (no remote state reads)
  project_prefix      = var.project_prefix
  build_suffix        = var.build_suffix
  azure_region        = var.azure_region
  resource_group_name = var.resource_group_name
  vnet_name           = var.vnet_name
  subnet_name         = var.subnet_name
  subnet_id           = var.subnet_id
  vnet_id             = var.vnet_id

  # AKS kubeconfig for XC service discovery
  kubeconfig = var.kubeconfig

  # Origin server: for k8s_pool, serviceName is used; otherwise empty
  origin_server   = var.serviceName != "" ? var.serviceName : ""
  origin_port     = var.serviceport != "" ? var.serviceport : "80"
  dns_origin_pool = false

  # Unused non-Azure fields (kept for template compatibility)
  vpc_id       = ""
  aws_region   = ""
  gcp_region   = ""
  vpc_name     = ""
  host         = ""
  cluster_name = ""
}
