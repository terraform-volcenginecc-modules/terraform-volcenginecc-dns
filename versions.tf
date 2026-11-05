terraform {
  required_version = ">= 1.5.7, < 1.12.0"

  required_providers {
    volcenginecc = {
      source  = "registry.terraform.io/volcengine/volcenginecc"
      version = ">= 0.0.60"
    }
  }
}
