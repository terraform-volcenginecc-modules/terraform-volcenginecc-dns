locals {
  zone_id = var.create_zone ? volcenginecc_dns_zone.this[0].zid : var.existing_zone_id
}

resource "volcenginecc_dns_zone" "this" {
  count = var.create_zone ? 1 : 0

  zone_name    = var.zone_name
  project_name = var.project_name
  remark       = var.zone_remark
  tags         = var.tags

  lifecycle {
    precondition {
      condition     = var.create_zone ? (var.zone_name != null && var.existing_zone_id == null) : (var.zone_name == null && var.existing_zone_id != null && var.project_name == null && var.zone_remark == null && var.tags == null)
      error_message = "Create mode requires zone_name and no existing_zone_id; existing mode requires existing_zone_id and no zone creation settings."
    }
  }
}

# A single Terraform owner for each individual record, even when the cloud
# groups several records into one record set.
resource "volcenginecc_dns_record" "this" {
  for_each = var.records

  zid    = local.zone_id
  host   = each.value.host
  type   = each.value.type
  value  = each.value.value
  ttl    = each.value.ttl
  line   = each.value.line
  remark = each.value.remark
  enable = each.value.enable
  weight = each.value.weight

  lifecycle {
    precondition {
      condition     = var.create_zone ? (var.zone_name != null && var.existing_zone_id == null) : (var.zone_name == null && var.existing_zone_id != null && var.project_name == null && var.zone_remark == null && var.tags == null)
      error_message = "Create mode requires zone_name and no existing_zone_id; existing mode requires existing_zone_id and no zone creation settings."
    }
    precondition {
      condition     = each.value.weight == null || (!var.create_zone && var.acknowledge_external_weighted_routing)
      error_message = "Explicit weight requires an existing zone and acknowledge_external_weighted_routing=true after externally enabling load balancing for every affected record set."
    }
  }
}
