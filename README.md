# terraform-volcenginecc-dns

Manage public DNS zones and individual records with VolcengineCC, including line routing and weighted routing enabled by the caller.

## 1. Overview

Create a public DNS zone and manage its A, AAAA, CNAME, MX, TXT, NS and SRV records, or manage records in a caller-owned zone by ID. Stable logical names identify records, which reference their zone ID. The caller manages domain registration, ownership verification, NS delegation, service endpoints and record-set load-balancing settings.

## 2. Usage

Prepare a registered domain you can manage, service addresses, and a Volcengine account with permission to manage DNS zones and records. Use Terraform 1.5.7, configure the provider in the calling project, and set `VOLCENGINE_ACCESS_KEY` and `VOLCENGINE_SECRET_KEY` through the runtime environment.

The following `example.com` and `192.0.2.10` illustrate the configuration format. Replace them with your domain and website IPv4 address:

```hcl
terraform {
  required_version = ">= 1.5.7, < 1.12.0"

  required_providers {
    volcenginecc = {
      source  = "registry.terraform.io/volcengine/volcenginecc"
      version = ">= 0.0.60"
    }
  }
}

provider "volcenginecc" {
  region = "cn-beijing"
}

module "dns" {
  source  = "terraform-volcenginecc-modules/dns/volcenginecc"
  version = "~> 1.0"

  zone_name = "example.com"
  records = {
    website = {
      host  = "www"
      type  = "A"
      value = "192.0.2.10"
    }
  }
}
```

With the default `create_zone=true`, this configuration creates one zone and one `www` A record. To use an existing zone, set `create_zone=false` and `existing_zone_id`, and keep `zone_name`, `project_name`, `zone_remark` and `tags` as `null`. This mode manages only the records declared in `records`; it does not query or take ownership of the existing zone.

Run from the calling project directory. Use `-parallelism=1` for both Apply and Destroy to execute resource operations sequentially within this Terraform run. Set concurrency through execution arguments; it is not a module input.

```shell
terraform init
terraform plan
terraform apply -parallelism=1
```

After creating a zone, configure every returned `name_servers` entry at the registrar, or delegate a subdomain zone with NS records in its parent zone. Complete ownership verification if Cloud DNS requests domain recovery. In `zone_status`, `cache_stage=0` means the account can manage the domain, `is_ns_correct=true` means the NS configuration is correct, and `stage=0` means the zone is normal. Account ownership status does not establish domain registration or delegation.

After delegation takes effect, query the actual service names through a normal recursive DNS resolver and check the record values. Querying an assigned authoritative server directly does not confirm public delegation. Destroy the resources only when they are no longer needed:

```shell
terraform plan
terraform destroy -parallelism=1
```

The second Plan after Apply should show no changes. Before destroying resources, review zone and record ownership and migrate any service records that must remain available.

## 3. Examples

- basic: Run in `examples/basic` to create a zone and one website A record for a registered domain. Outputs include the zone ID, name servers, zone status and record IDs. Supply the domain, website IPv4 address and permission to change registrar settings.
- complete: Run in `examples/complete` to configure A, AAAA, CNAME, MX, SPF TXT, a disabled TXT record and a non-default API line with a default fallback. Create a zone with project and tags, or manage records in an existing zone. The separate `dns_ipv6` call creates AAAA after the other records. The optional 80/20 weighted scenario requires an existing zone and externally enabled record-set load balancing.

## 4. Requirements

| Name | Version |
|---|---|
| Terraform | `>= 1.5.7, < 1.12.0` |
| `volcengine/volcenginecc` | `>= 0.0.60` |

The operating steps use Terraform 1.5.7. The module constraint `version = "~> 1.0"` is configured separately from the provider version constraint.

## 5. Providers

| Name | Source |
|---|---|
| `volcenginecc` | `registry.terraform.io/volcengine/volcenginecc` |

The caller configures the provider region and authentication. This module does not declare provider aliases.

## 6. Resources

| Mode | Type | Name |
|---|---|---|
| Create a zone, `create_zone=true` | Resource: `volcenginecc_dns_zone` | [`volcenginecc_dns_zone.this[0]`](https://registry.terraform.io/providers/volcengine/volcenginecc/latest/docs/resources/dns_zone) |
| Create a zone or use an existing zone | Resource: `volcenginecc_dns_record` | [`volcenginecc_dns_record.this[key]`](https://registry.terraform.io/providers/volcengine/volcenginecc/latest/docs/resources/dns_record) |

The zone resource creates at most one instance. The number of record instances is determined by the entries in `records`. Each entry manages one individual record, even when the service groups several records into one record set. This module declares no data sources.

## 7. Inputs

| Name | Type | Default | Required in create mode | Description |
|---|---|---|---|---|
| `create_zone` | `bool` | `true` | No | Whether to create and manage the zone; cannot be `null`. Choose the ownership mode before the first Apply. |
| `zone_name` | `string` | `null` | Yes | Registered public domain in lowercase ASCII or punycode, at most 253 characters, with valid labels and no trailing dot. Keep `null` in existing-zone mode. |
| `existing_zone_id` | `string` | `null` | No | Required in existing-zone mode; cannot be empty after trimming whitespace. Keep `null` in create mode. The caller retains ownership of the existing zone. |
| `project_name` | `string` | `null` | No | Project for the created zone; cannot be a blank string when supplied. `null` uses provider defaults. Keep `null` in existing-zone mode. |
| `zone_remark` | `string` | `null` | No | Remark for the created zone; `null` leaves it unspecified. Keep `null` in existing-zone mode. |
| `tags` | `set(object({key=string,value=string}))` | `null` | No | Tags for the created zone. When supplied, the set must be nonempty, keys unique and nonblank, and values explicitly provided and non-null; empty values are allowed. Keep `null` in existing-zone mode. |
| `acknowledge_external_weighted_routing` | `bool` | `false` | No | Cannot be `null`. Set to `true` in existing-zone mode when specifying weights, after externally enabling load balancing on every affected record set. This input neither enables nor checks the switch. |
| `records` | `map(object)`, expanded below | none | Yes | Records keyed by stable logical names. Cannot be `null`, but may be `{}`. Required in both modes; keys cannot be blank. |
| `records.host` | `string` | none | Required per record | Relative host prefix; `@` represents the domain apex. Cannot be blank. Do not replace a host prefix with the full zone name. |
| `records.type` | `string` | none | Required per record | Uppercase `A`, `AAAA`, `CNAME`, `MX`, `TXT`, `NS` or `SRV`. |
| `records.value` | `string` | none | Required per record | Nonblank record value. A requires IPv4, AAAA requires IPv6, and MX uses `priority target` with priority 1–99, such as `10 mail.example.com`. Other types follow their DNS formats. |
| `records.ttl` | `number` | `600` | No | Positive integer in seconds, within the domain edition's limits. |
| `records.line` | `string` | `"default"` | No | Nonblank line code. Obtain non-default codes from ListLines/ListCustomLines and confirm that the domain edition permits them. |
| `records.remark` | `string` | `""` | No | Individual record remark, at most 16 characters. |
| `records.enable` | `bool` | `true` | No | Whether the record is enabled. `false` retains its configuration but does not serve that record in DNS answers. |
| `records.weight` | `number` | `null` | No | Nonnegative integer for A, AAAA or CNAME only. Requires existing-zone mode, externally enabled load balancing and the acknowledgement input. |

The complete object type for `records` is:

```hcl
map(object({
  host   = string
  type   = string
  value  = string
  ttl    = optional(number, 600)
  line   = optional(string, "default")
  remark = optional(string, "")
  enable = optional(bool, true)
  weight = optional(number)
}))
```

Records in the same `host/type/line` group must share a TTL and either all specify weights or all omit them. Duplicate `host/type/line/value` entries are rejected, as is CNAME coexistence with other types at the same host and line. Host comparisons are case-insensitive. These checks cover only the declared records; inspect external records for conflicts when using an existing zone. Consult the [record type formats](https://www.volcengine.com/docs/6758/145121) for complete value syntax.

## 8. Outputs

| Name | Type | Description |
|---|---|---|
| `zone_id` | `string` | Created zone ZID or supplied existing zone ID, for associating other DNS configurations. |
| `name_servers` | `set(string)` | All authoritative servers assigned to a created zone, for registrar or parent-zone NS delegation. `null` in existing-zone mode. |
| `zone_status` | `object({stage=number,cache_stage=number,is_ns_correct=bool})` | Created-zone status, account ownership and NS configuration indicators. `null` in existing-zone mode, where the caller checks these separately. |
| `record_ids` | `map(string)` | Logical names mapped to cloud RecordIDs. `{}` when there are no records. |
| `record_set_ids` | `map(string)` | Logical names mapped to read-only cloud RecordSetIDs for locating record sets. Values follow the provider response and may be `null`; they do not imply ownership of record-set settings. |
| `records` | `map(object({pqdn=string,type=string,ttl=number,line=string,enable=bool,weight=number}))` | Host name, type, TTL, line, enabled status and weight by logical name. `{}` when there are no records. Returned `weight` values cannot establish whether load balancing is enabled. |

## 9. Notes

- Set concurrency to 1 for Apply and Destroy. Use `terraform apply -parallelism=1` and `terraform destroy -parallelism=1` to execute resource operations sequentially. Pass this setting through the execution command.
- Choose zone ownership before the first Apply. Destroy in create mode removes the zone and records managed by this configuration. Existing-zone mode removes only the declared records and preserves the zone. Migrate service records that must remain available before destroying a created zone.
- Keep logical keys in `records` stable. Renaming or removing a key changes the corresponding resource address. Before changing the domain, host, value or other settings, review the planned additions, updates and deletions and arrange any required DNS cutover.
- The module does not discover or adopt existing records automatically. Match configuration to each existing record and import it with `ZID|RecordID` into `module.dns.volcenginecc_dns_record.this["logical_name"]`. To adopt a zone in create mode, import its ZID into `module.dns.volcenginecc_dns_zone.this[0]`. Do not import the zone in existing-zone mode.
- A `null` project, zone remark or tag set leaves that setting unspecified. To remove an existing setting, review the provider's plan and the resulting cloud configuration.
- Enable weighted routing for the exact host, type and line record set through the console or [UpdateRecordSet](https://www.volcengine.com/docs/6758/155111) first. The caller maintains this switch; the module configures only individual record weights. Weight values do not guarantee actual request proportions.
- The default line provides a fallback for source matching, without checking service health. CNAME is an ordinary DNS alias. Paid domain features, renewal, health checks and cloud-resource alias targets are outside this module's management scope.
- After deployment, run a normal `terraform plan` again and require no changes for idempotence. Following a DNS change or deletion, recursive resolvers may keep returning cached answers until the original TTL expires.
