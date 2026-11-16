# COMPLETE Public DNS Example

## 1. Overview

Configure website IPv4/IPv6, CNAME, mail A/MX, SPF TXT, a disabled TXT record and API line routing with a default fallback. Create a zone with project and tags, or manage an existing zone's records. Optional weights require external load balancing. Supply the domain, service addresses, permitted line code and NS permissions. Compared with basic, this covers more record types and routing scenarios.

## 2. Usage

Use Terraform 1.5.7 and run from `examples/complete`. Set `VOLCENGINE_ACCESS_KEY` and `VOLCENGINE_SECRET_KEY` through the runtime environment. The account needs permission to manage the relevant zone and records.

Use `-parallelism=1` for both Apply and Destroy to execute all resource operations sequentially within this run; `depends_on` orders the two module calls. Set concurrency through execution arguments; it is not a module input.

1. Edit `terraform.tfvars` in this directory. The following domain and addresses illustrate the format; replace them with your registered domain and actual service addresses. Select `routing_line` from ListLines/ListCustomLines according to the domain edition. It cannot be `"default"`.

   ```hcl
   region                          = "cn-beijing"
   zone_name                       = "example.com"
   existing_zone_id                = null
   project_name                    = "default"
   website_ipv4                    = "192.0.2.10"
   website_ipv6                    = "2001:db8::10"
   mail_ipv4                       = "192.0.2.20"
   regional_api_ipv4               = "192.0.2.30"
   routing_line                    = "mobile"
   enable_weighted_routing_example = false
   ```

   With `existing_zone_id=null`, the example creates a zone with `project_name`, the `DNS complete` remark and the tags `Environment=development` and `ManagedBy=Terraform`. To use an existing zone, supply its actual ID. `zone_name` remains required and must match that zone; zone project, remark and tags are not passed to the module. Choose the mode and inspect existing records for conflicts before the first Apply.

2. Initialize and review the first plan. The default create mode adds one zone and nine records; existing-zone mode adds only nine records.

   ```shell
   terraform init
   terraform plan
   ```

3. Create the resources and inspect outputs. `module.dns` manages the zone and other records; `module.dns_ipv6` creates AAAA after that call completes. Record outputs merge both calls.

   ```shell
   terraform apply -parallelism=1
   terraform output
   ```

   In create mode, configure `name_servers` at the registrar or establish subdomain NS delegation in the parent zone, and complete any required ownership verification. In existing-zone mode, `name_servers` and `zone_status` are `null`; the caller checks zone ownership and delegation separately. The domain should be registered, its NS configuration correct and its status normal.

   After delegation takes effect, use normal recursive resolvers to check apex A/AAAA, `www` CNAME, `mail` A, MX with priority 10 and SPF TXT. Enabled business records use TTL 600; `maintenance` should return no TXT record. Query the API from a client matching the selected line and from other sources to check the default fallback. Source-based routing does not check service health.

4. Once the configuration is stable, check the plan again. Expect no changes.

   ```shell
   terraform plan
   ```

5. Review the deletion scope and destroy the resources. The dependency removes AAAA first, followed by other records and any zone created by this configuration.

   ```shell
   terraform destroy -parallelism=1
   ```

Optional weights require an existing zone. First prepare `weighted/A/default` externally and enable its load balancing. Then set `enable_weighted_routing_example=true` and use different `website_ipv4` and `regional_api_ipv4` addresses. This branch adds `weighted_primary` and `weighted_secondary`, with weights 80 and 20. Import any existing values with `ZID|RecordID` into `module.dns.volcenginecc_dns_record.this["weighted_primary"]` and `module.dns.volcenginecc_dns_record.this["weighted_secondary"]`, then review the plan and apply to avoid duplicate creation. The module does not enable or check the external load-balancing switch.

## 3. Requirements

| Name | Version |
|---|---|
| Terraform | `>= 1.5.7, < 1.12.0` |
| `volcengine/volcenginecc` | `>= 0.0.60` |

The operating steps use Terraform 1.5.7.

## 4. Providers

| Name | Source |
|---|---|
| `volcenginecc` | `registry.terraform.io/volcengine/volcenginecc` |

Both module calls share the provider configured in this directory, without aliases.

## 5. Resources

| Name | Description |
|---|---|
| `module.dns` | Uses `source = "terraform-volcenginecc-modules/dns/volcenginecc"` and `version = "~> 1.0"`. Creates a zone or uses an existing zone according to the selected mode, and manages eight base records plus two optional weighted records. |
| `module.dns_ipv6` | Uses `source = "terraform-volcenginecc-modules/dns/volcenginecc"` and `version = "~> 1.0"`. Depends on `module.dns` and uses its `zone_id` to manage one apex AAAA record. |

This example root declares no resources or data sources directly.

## 6. Inputs

| Name | Description |
|---|---|
| `region` | Provider region; defaults to `"cn-beijing"`. |
| `zone_name` | Required, with no default. Registered domain you can manage; also supplies the CNAME and MX targets. Must match the domain identified by `existing_zone_id` in existing-zone mode. |
| `existing_zone_id` | Optional; defaults to `null`. When null, create a zone; when a nonempty zone ID is supplied, manage only that zone's records. Choose the mode before the first Apply. |
| `project_name` | Project for a created zone; defaults to `"default"`. Not used in existing-zone mode. |
| `website_ipv4` | Required, with no default. Apex A and default API address; also supplies the optional primary weighted record. |
| `website_ipv6` | Required, with no default. Apex AAAA address managed by `dns_ipv6`. |
| `mail_ipv4` | Required, with no default. `mail` A address; the apex MX points to `mail.zone_name`. |
| `regional_api_ipv4` | Required, with no default. Non-default API address and optional secondary weighted address. Use a different address from the primary when enabling weights. |
| `routing_line` | Required, with no default. Non-default line code permitted by the domain edition; cannot be blank or `"default"`. |
| `enable_weighted_routing_example` | Defaults to `false`. When `true`, use an existing zone and externally enable load balancing on `weighted/A/default` first. |

## 7. Outputs

| Name | Description |
|---|---|
| `zone_id` | Created zone ZID or supplied existing zone ID. |
| `name_servers` | Authoritative servers assigned to a created zone. `null` in existing-zone mode; obtain them from the zone owner. |
| `zone_status` | Created-zone status, account ownership and NS configuration indicators. `null` in existing-zone mode. |
| `record_ids` | RecordID map merged from both calls, including `ipv6`. Enabling weights adds two weighted keys. |
| `record_set_ids` | Read-only RecordSetID map merged from both calls, for locating record sets without adopting their load-balancing settings. |
| `records` | Host name, type, TTL, line, enabled status and weight merged from both calls, for checking record configuration. Returned weights do not establish whether the weighted-routing switch is enabled. |

## 8. Example

This directory contains the complete example for multiple record types, mail settings, source-based line routing or existing-zone record management. The default configuration has nine records; the optional weighted branch adds two. Basic creates only a zone and one website A record.

## 9. Notes

- Set concurrency to 1 for Apply and Destroy. Use `terraform apply -parallelism=1` and `terraform destroy -parallelism=1` to execute all resource operations sequentially. `depends_on` orders the two module calls; set concurrency through the execution command.
- Supply credentials through the provider-supported runtime environment, not through source files or `terraform.tfvars`.
- Run `terraform plan` again after Apply. Idempotence requires the result to show no changes.
- Destroy in create mode removes the zone and records created by this configuration. Existing-zone mode preserves the zone and removes only managed records. External load-balancing switches and other records remain under their original owners; records imported into this configuration are also deleted.
- The caller confirms the relationship between `zone_name` and the existing zone ID. After checking NS and account ownership status, query normal recursive resolvers to confirm public answers. Direct authoritative queries cannot establish registrar delegation.
- When upgrading a configuration with the old AAAA address, retain the existing `moved` block from `module.dns.volcenginecc_dns_record.this["ipv6"]` to `module.dns_ipv6.volcenginecc_dns_record.this["ipv6"]`. Review the plan to confirm that an unchanged record only moves its address.
- Weights of 80/20 configure records; actual request proportions depend on DNS caching and client behavior. The default line is a source-based fallback, not health-based failover.
- Migrate service records that must remain available before deleting a created zone. Following a record change or deletion, recursive resolvers may keep returning cached answers until the original TTL expires.
