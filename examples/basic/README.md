# BASIC Public DNS Example

## 1. Overview

Create one public DNS zone and one `www` A record for a registered domain, with zone, name-server and record outputs. Supply the domain, website IPv4 address and permission to change NS settings. Compared with complete, this example provides only minimal website resolution, without IPv6, mail, multiple lines or weighted configuration.

## 2. Usage

Use Terraform 1.5.7 and run from `examples/basic`. Set `VOLCENGINE_ACCESS_KEY` and `VOLCENGINE_SECRET_KEY` through the runtime environment. The account needs permission to manage DNS zones and records.

Use `-parallelism=1` for both Apply and Destroy to execute resource operations sequentially within this run. Set concurrency through execution arguments; it is not a module input.

1. Edit `terraform.tfvars` in this directory. The domain and IP below illustrate the format; replace them with a registered domain you can manage and your website's public IPv4 address. This configuration should manage the domain independently.

   ```hcl
   region       = "cn-beijing"
   zone_name    = "example.com"
   website_ipv4 = "192.0.2.10"
   ```

2. Initialize and review the first plan. Expect one new zone and one `www` A record.

   ```shell
   terraform init
   terraform plan
   ```

3. Create the resources and inspect the assigned name servers and zone status.

   ```shell
   terraform apply -parallelism=1
   terraform output name_servers
   terraform output zone_status
   ```

   Configure all name servers at the registrar, or delegate a subdomain zone through NS records in its parent zone. Complete ownership verification in the console if the domain is pending recovery. Confirm `cache_stage=0`, `is_ns_correct=true` and `stage=0`, then query the `www` A record through a normal recursive resolver. Expect `website_ipv4` with a business-record TTL of 600 seconds.

4. Once the configuration is stable, check the plan again. Expect no changes.

   ```shell
   terraform plan
   ```

5. Destroy the resources when the zone and website record are no longer needed.

   ```shell
   terraform destroy -parallelism=1
   ```

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

This directory configures the provider through `region` and does not use aliases.

## 5. Resources

| Name | Description |
|---|---|
| `module.dns` | Uses `source = "terraform-volcenginecc-modules/dns/volcenginecc"` and `version = "~> 1.0"` to create the zone and one website A record. |

This example root declares no resources or data sources directly.

## 6. Inputs

| Name | Description |
|---|---|
| `region` | Provider region; defaults to `"cn-beijing"`. |
| `zone_name` | Required, with no default. A registered domain you can manage, in lowercase ASCII or punycode without a trailing dot. Do not manage it in another Terraform configuration simultaneously. |
| `website_ipv4` | Required, with no default. Website public IPv4 address for the `www` A record. |

## 7. Outputs

| Name | Description |
|---|---|
| `zone_id` | Created zone ZID, for locating the zone or associating other DNS configurations. |
| `name_servers` | All assigned authoritative name servers, to configure at the registrar or parent zone. |
| `zone_status` | `stage`, `cache_stage` and `is_ns_correct`, for checking zone status, account ownership and NS configuration. |
| `record_ids` | Contains the `website` key and its cloud RecordID for locating the website record. |

## 8. Example

This directory contains the basic example for a new zone requiring only one website IPv4 record. Use complete for multiple record types, non-default lines or an existing zone.

## 9. Notes

- Set concurrency to 1 for Apply and Destroy. Use `terraform apply -parallelism=1` and `terraform destroy -parallelism=1` to execute resource operations sequentially. Pass this setting through the execution command.
- Supply credentials through the provider-supported runtime environment, not through source files or `terraform.tfvars`.
- Run `terraform plan` again after Apply. Idempotence requires the result to show no changes.
- This configuration manages the created zone and website record; Destroy removes both. Domain registration, NS delegation and the website server remain caller-managed and are not deleted by this configuration.
- Configure NS delegation after creating the zone. `cache_stage=0` means the account can manage the zone; it alone cannot establish public resolution. Check website answers through a normal recursive DNS resolver.
- Migrate records that must remain available before destroying the zone. Following record deletion, recursive resolvers may keep returning cached answers until the original TTL expires.
