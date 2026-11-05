variable "region" {
  description = "Provider region."
  type        = string
  default     = "cn-beijing"
}

variable "zone_name" {
  description = "Registered domain. In existing mode it must match the domain of existing_zone_id; the module cannot verify that association."
  type        = string
}

variable "existing_zone_id" {
  description = "Optional caller-owned zone ID. Choose the ownership mode before first apply; never switch modes in place."
  type        = string
  default     = null
}

variable "project_name" {
  description = "Project for a created zone."
  type        = string
  default     = "default"
}

variable "website_ipv4" {
  description = "Website IPv4 and default API route."
  type        = string
}

variable "website_ipv6" {
  description = "Website IPv6."
  type        = string
}

variable "mail_ipv4" {
  description = "Mail server IPv4."
  type        = string
}

variable "regional_api_ipv4" {
  description = "API route IPv4 for the specified line."
  type        = string
}

variable "routing_line" {
  description = "Non-default public DNS line code returned by ListLines/ListCustomLines and permitted by your DNS edition."
  type        = string
  validation {
    condition     = length(trimspace(var.routing_line)) > 0 && var.routing_line != "default"
    error_message = "routing_line must be a non-default line code permitted by the domain's DNS edition."
  }
}

variable "enable_weighted_routing_example" {
  description = "Only set true for an existing zone after enabling load balancing externally on weighted/A/default. 80/20 weights are configuration intent, not verified traffic percentages."
  type        = bool
  default     = false
}
