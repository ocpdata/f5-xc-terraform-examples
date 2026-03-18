# Fetch AKS created Vnet
data "azurerm_resources" "vnet" {
  count               = var.use_new_vnet ? 1 : 0
  type                = "Microsoft.Network/virtualNetworks"
  resource_group_name = local.aks_resource_group_name
  depends_on          = [azurerm_kubernetes_cluster.ce_waap]
}

# Fetch Loadbalancer External IP address
data "azurerm_lb" "lb" {
  count               = var.use_new_vnet ? 1 : 0
  name                = "kubernetes-internal"
  resource_group_name = local.aks_resource_group_name
  depends_on          = [time_sleep.wait_30_seconds, azurerm_kubernetes_cluster.ce_waap]
}

# Fetch AKS created Vnet details
data "azurerm_virtual_network" "aks-vnet" {
  count               = var.use_new_vnet ? 1 : 0
  name                = data.azurerm_resources.vnet[0].resources[0].name
  resource_group_name = local.aks_resource_group_name
}

# Fetch AKS created subnet details
data "azurerm_subnet" "aks-subnet" {
  count                = var.use_new_vnet ? 1 : 0
  name                 = data.azurerm_virtual_network.aks-vnet[0].subnets[0]
  resource_group_name  = local.aks_resource_group_name
  virtual_network_name = data.azurerm_resources.vnet[0].resources[0].name
}

# Read the long-lived service account token for XC service discovery
# depends_on time_sleep.wait_for_sa_token ensures:
#   1. kubectl apply -f manifest.yaml has already run (null_resource.deploy-yaml)
#   2. Kubernetes has had time to auto-populate the token into the Secret
data "kubernetes_secret" "xc_sd_token" {
  metadata {
    name      = "xc-service-discovery-token"
    namespace = "default"
  }
  depends_on = [time_sleep.wait_for_sa_token]
}
