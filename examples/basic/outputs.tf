output "zone_id" {
  description = "Created public DNS zone ID."
  value       = module.dns.zone_id
}

output "name_servers" {
  description = "Name servers to configure at your domain registrar."
  value       = module.dns.name_servers
}

output "zone_status" {
  description = "Domain ownership and name-server delegation status."
  value       = module.dns.zone_status
}

output "record_ids" {
  description = "Record IDs by logical key."
  value       = module.dns.record_ids
}
