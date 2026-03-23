data "volterra_api_definition" "api-def" {
  count     = var.xc_api_pro ? 1 : 0
  name      = var.xc_api_def_name
  namespace = var.xc_namespace
}