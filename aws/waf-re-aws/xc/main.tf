provider "volterra" {
  url          = var.api_url
  api_p12_file = "./api.p12"
  p12_password = var.p12_password
}
