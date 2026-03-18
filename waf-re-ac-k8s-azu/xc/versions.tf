terraform {
  required_version = ">= 0.14.0"
  required_providers {
    volterra = {
      source  = "volterraedge/volterra"
      version = ">= 0.11.34"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.18.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">=0.9.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">=3.0.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">=2.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">=3.0.0"
    }
  }
}
