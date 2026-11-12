provider "volcenginecc" {
  region = var.region
}

module "dns" {
  source  = "terraform-volcenginecc-modules/dns/volcenginecc"
  version = "~> 1.0"

  zone_name = var.zone_name
  records = {
    website = {
      host  = "www"
      type  = "A"
      value = var.website_ipv4
    }
  }
}
