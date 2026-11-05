variable "region" {
  description = "Provider region configured by the caller."
  type        = string
  default     = "cn-beijing"
}

variable "zone_name" {
  description = "Your registered domain, not already managed as a DNS zone elsewhere in Terraform."
  type        = string
}

variable "website_ipv4" {
  description = "Public IPv4 address of your website."
  type        = string
}
