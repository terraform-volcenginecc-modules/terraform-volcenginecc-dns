variable "create_zone" {
  description = "Create and own a public DNS zone. Do not switch ownership modes at the same module address."
  type        = bool
  default     = true
  nullable    = false
}

variable "zone_name" {
  description = "Registered public domain in lowercase ASCII or punycode, without a trailing dot; required in create mode."
  type        = string
  default     = null

  validation {
    condition     = var.zone_name == null ? true : (length(var.zone_name) <= 253 && can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]([a-z0-9-]{0,61}[a-z0-9])?$", var.zone_name)))
    error_message = "zone_name must be a lowercase public DNS name with valid labels, without a trailing dot."
  }
}

variable "existing_zone_id" {
  description = "Caller-owned public DNS zone ID. Required when create_zone=false; never read, import, update or destroy the external zone."
  type        = string
  default     = null

  validation {
    condition     = var.existing_zone_id == null ? true : length(trimspace(var.existing_zone_id)) > 0
    error_message = "existing_zone_id must be nonempty when specified."
  }
}

variable "project_name" {
  description = "Project for the created zone; null leaves the provider default. Not accepted in existing mode."
  type        = string
  default     = null

  validation {
    condition     = var.project_name == null ? true : length(trimspace(var.project_name)) > 0
    error_message = "project_name must be nonempty when specified."
  }
}

variable "zone_remark" {
  description = "Remark for the created zone; null leaves the provider default. Not accepted in existing mode."
  type        = string
  default     = null
}

variable "tags" {
  description = "Nonempty set of explicit key/value tags for the created zone. Null leaves tags unspecified; clearing is not verified."
  type = set(object({
    key   = string
    value = string
  }))
  default = null

  validation {
    condition = var.tags == null ? true : (
      length(var.tags) > 0 &&
      alltrue([for tag in var.tags : try(length(trimspace(tag.key)) > 0 && tag.value != null, false)]) &&
      length(distinct([for tag in var.tags : tag.key])) == length(var.tags)
    )
    error_message = "tags must be null or a nonempty set with unique nonempty keys and explicit non-null values."
  }
}

variable "acknowledge_external_weighted_routing" {
  description = "Acknowledge that the caller already enabled load balancing for all weighted record sets in the existing zone. This module cannot enable or verify that switch."
  type        = bool
  default     = false
  nullable    = false
}

variable "records" {
  description = "Individual DNS records keyed by stable logical names. MX values include priority (1-99) and target; line codes and TTL limits depend on the DNS edition. Weight only applies to externally enabled A/AAAA/CNAME record sets."
  type = map(object({
    host   = string
    type   = string
    value  = string
    ttl    = optional(number, 600)
    line   = optional(string, "default")
    remark = optional(string, "")
    enable = optional(bool, true)
    weight = optional(number)
  }))
  nullable = false

  validation {
    condition = alltrue([for key, record in var.records :
      length(trimspace(key)) > 0 &&
      try(length(trimspace(record.host)) > 0 && length(trimspace(record.value)) > 0, false) &&
      contains(["A", "AAAA", "CNAME", "MX", "TXT", "NS", "SRV"], record.type)
    ])
    error_message = "records require nonempty keys, host and value, and a supported uppercase type: A, AAAA, CNAME, MX, TXT, NS or SRV."
  }
  validation {
    condition = alltrue([for record in var.records :
      record.ttl > 0 && floor(record.ttl) == record.ttl &&
      length(trimspace(record.line)) > 0 && length(record.remark) <= 16 &&
      (record.weight == null ? true : (record.weight >= 0 && floor(record.weight) == record.weight && contains(["A", "AAAA", "CNAME"], record.type)))
    ])
    error_message = "records require a positive integer TTL, nonempty line, remark at most 16 characters, and optional nonnegative integer weight only for A/AAAA/CNAME."
  }
  validation {
    condition = alltrue([for record in var.records :
      record.type == "A" ? can(cidrnetmask("${record.value}/32")) :
      record.type == "AAAA" ? (can(cidrhost("${record.value}/128", 0)) && can(regex(":", record.value))) :
      record.type == "MX" ? can(regex("^[1-9][0-9]? [^ ]+\\.[^ ]+\\.?$", record.value)) : true
    ])
    error_message = "A values must be IPv4, AAAA values IPv6, and MX values must be 'priority target' with priority 1-99."
  }
  validation {
    condition = length(distinct([for record in var.records :
      jsonencode([lower(record.host), record.type, record.line, record.value])
    ])) == length(var.records)
    error_message = "Duplicate host/type/line/value records are not allowed."
  }
  validation {
    condition = alltrue(flatten([for record in var.records : [
      for other in var.records :
      lower(record.host) != lower(other.host) || record.line != other.line ||
      record.type == other.type || (record.type != "CNAME" && other.type != "CNAME")
    ]]))
    error_message = "CNAME cannot coexist with other record types at the same host and line in this module."
  }
  validation {
    condition = alltrue(flatten([for record in var.records : [
      for other in var.records :
      lower(record.host) != lower(other.host) || record.type != other.type || record.line != other.line ||
      (record.ttl == other.ttl && (record.weight == null) == (other.weight == null))
    ]]))
    error_message = "Records in the same host/type/line group must share TTL and either all specify weight or all omit it."
  }
}
