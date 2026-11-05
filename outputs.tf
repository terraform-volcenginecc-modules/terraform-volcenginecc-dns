output "zone_id" {
  description = "Created zone ZID or caller-supplied existing zone ID."
  value       = local.zone_id
  precondition {
    condition     = var.create_zone ? (var.zone_name != null && var.existing_zone_id == null) : (var.zone_name == null && var.existing_zone_id != null && var.project_name == null && var.zone_remark == null && var.tags == null)
    error_message = "Create mode requires zone_name and no existing_zone_id; existing mode requires existing_zone_id and no zone creation settings."
  }
}

output "name_servers" {
  description = "Assigned authoritative name servers for a created zone; null for an external zone, which this module does not query."
  value       = var.create_zone ? volcenginecc_dns_zone.this[0].allocate_dns_server_list : null
}

output "zone_status" {
  description = "Read-only stage, cache_stage (ownership) and is_ns_correct for a created zone; null for external mode."
  value = var.create_zone ? {
    stage         = volcenginecc_dns_zone.this[0].stage
    cache_stage   = volcenginecc_dns_zone.this[0].cache_stage
    is_ns_correct = volcenginecc_dns_zone.this[0].is_ns_correct
  } : null
}

output "record_ids" {
  description = "Cloud RecordID by stable logical record key; empty when records is empty."
  value       = { for key, record in volcenginecc_dns_record.this : key => record.record_id }
}

output "record_set_ids" {
  description = "Read-only cloud RecordSetID by logical record key; normally null for types other than A/AAAA/CNAME. Does not confer ownership of record-set settings."
  value       = { for key, record in volcenginecc_dns_record.this : key => record.record_set_id }
}

output "records" {
  description = "Read-back PQDN, type, TTL, line, enable and weight by logical key. Never use weight alone as evidence that weighted routing is enabled."
  value = { for key, record in volcenginecc_dns_record.this : key => {
    pqdn   = record.pqdn
    type   = record.type
    ttl    = record.ttl
    line   = record.line
    enable = record.enable
    weight = record.weight
  } }
}
