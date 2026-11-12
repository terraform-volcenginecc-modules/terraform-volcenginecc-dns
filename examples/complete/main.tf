provider "volcenginecc" {
  region = var.region
}

module "dns" {
  source  = "terraform-volcenginecc-modules/dns/volcenginecc"
  version = "~> 1.0"

  create_zone      = var.existing_zone_id == null
  existing_zone_id = var.existing_zone_id
  zone_name        = var.existing_zone_id == null ? var.zone_name : null
  project_name     = var.existing_zone_id == null ? var.project_name : null
  zone_remark      = var.existing_zone_id == null ? "DNS complete" : null
  tags = var.existing_zone_id == null ? [
    { key = "Environment", value = "development" },
    { key = "ManagedBy", value = "Terraform" }
  ] : null

  acknowledge_external_weighted_routing = var.enable_weighted_routing_example
  records = merge({
    apex = {
      host = "@", type = "A", value = var.website_ipv4
      ttl  = 600, line = "default", remark = "Website", enable = true
    }
    www = {
      host = "www", type = "CNAME", value = var.zone_name
      ttl  = 600, line = "default", remark = "Website CNAME", enable = true
    }
    mail = {
      host = "mail", type = "A", value = var.mail_ipv4
      ttl  = 600, line = "default", remark = "Mail server", enable = true
    }
    mx = {
      host = "@", type = "MX", value = "10 mail.${var.zone_name}"
      ttl  = 600, line = "default", remark = "Mail routing", enable = true
    }
    spf = {
      host = "@", type = "TXT", value = "v=spf1 mx -all"
      ttl  = 600, line = "default", remark = "SPF", enable = true
    }
    regional_api = {
      host = "api", type = "A", value = var.regional_api_ipv4
      ttl  = 600, line = var.routing_line, remark = "Line routing", enable = true
    }
    default_api = {
      host = "api", type = "A", value = var.website_ipv4
      ttl  = 600, line = "default", remark = "Default route", enable = true
    }
    disabled = {
      host = "maintenance", type = "TXT", value = "maintenance"
      ttl  = 600, line = "default", remark = "Disabled record", enable = false
    }
    }, var.enable_weighted_routing_example ? {
    weighted_primary = {
      host = "weighted", type = "A", value = var.website_ipv4
      ttl  = 600, line = "default", remark = "Weight primary", enable = true, weight = 80
    }
    weighted_secondary = {
      host = "weighted", type = "A", value = var.regional_api_ipv4
      ttl  = 600, line = "default", remark = "Weight secondary", enable = true, weight = 20
    }
  } : {})
}

# Avoid concurrent AAAA and other record writes to the same zone.
module "dns_ipv6" {
  source  = "terraform-volcenginecc-modules/dns/volcenginecc"
  version = "~> 1.0"

  depends_on = [module.dns]

  create_zone      = false
  existing_zone_id = module.dns.zone_id
  records = {
    ipv6 = {
      host = "@", type = "AAAA", value = var.website_ipv6
      ttl  = 600, line = "default", remark = "IPv6 website", enable = true
    }
  }
}

# Preserve an existing AAAA record when upgrading this example.
moved {
  from = module.dns.volcenginecc_dns_record.this["ipv6"]
  to   = module.dns_ipv6.volcenginecc_dns_record.this["ipv6"]
}
