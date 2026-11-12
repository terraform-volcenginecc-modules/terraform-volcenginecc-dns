output "zone_id" {
  description = "Created or caller-owned public DNS zone ID."
  value       = module.dns.zone_id
}

output "name_servers" {
  description = "Assigned name servers; null in existing mode."
  value       = module.dns.name_servers
}

output "zone_status" {
  description = "Ownership and delegation status; null in existing mode."
  value       = module.dns.zone_status
}

output "record_ids" {
  description = "Record IDs by logical key."
  value       = merge(module.dns.record_ids, module.dns_ipv6.record_ids)
}

output "record_set_ids" {
  description = "Read-only record-set IDs by logical key."
  value       = merge(module.dns.record_set_ids, module.dns_ipv6.record_set_ids)
}

output "records" {
  description = "Provider read-back of managed records."
  value       = merge(module.dns.records, module.dns_ipv6.records)
}
