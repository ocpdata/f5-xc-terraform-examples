locals {
  azure_region        = var.azure_region
  resource_group_name = var.resource_group_name
  vnet_name           = var.vnet_name
  subnet_name         = var.subnet_name
  subnet_id           = var.subnet_id
  project_prefix      = var.project_prefix
  build_suffix        = var.build_suffix
  vnet_id             = var.vnet_id
  aks_resource_group_name = format("MC_%s-rg-%s_%s-aks-%s_%s",
    local.project_prefix, local.build_suffix,
    local.project_prefix, local.build_suffix,
    local.azure_region
  )
}
