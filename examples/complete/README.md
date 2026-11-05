# Complete public DNS

Configure website IPv4/IPv6, CNAME, mail MX/A, SPF TXT, a disabled record and API line routing with a default fallback. Create and own a zone with project/tags, or select an existing caller-owned zone before the first apply.

The module source is `terraform-volcenginecc-modules/dns/volcenginecc`. This draft has no published module version and Registry installation is not verified. Validation targets are Terraform 1.5.7 and OpenTofu 1.11.8 with provider 0.0.60 and 0.0.73; local checks rewrite source only in temporary copies.

Provide `zone_name`, `website_ipv4`, `website_ipv6`, `mail_ipv4`, `regional_api_ipv4` and `routing_line`. The line must come from public DNS ListLines/ListCustomLines and be allowed by your domain edition. The default API route supplies a fallback, not health-based failover. In existing mode set `existing_zone_id`, ensure it matches `zone_name`, and inspect or import existing records before applying. Never change ownership mode in place.

Credentials and `region` belong to the caller. Use a private variable file and credential manager.

```shell
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
terraform output
terraform plan -var-file=terraform.tfvars
```

In create mode configure the returned name servers at the registrar and complete domain ownership verification. In existing mode `name_servers` and `zone_status` are null; check delegation and ownership externally. Check DNS answers for each type, MX priority 10, TXT content and line routing, and verify the disabled record is inactive. Require a second plan with no changes.

For the optional weighted scenario, first enable load balancing outside Terraform for the exact `weighted`/`A`/`default` record set in an existing zone; preserve this setting under a separate owner. Then set `enable_weighted_routing_example=true` and supply `existing_zone_id`. Import any already existing primary/secondary records using `zid|record_id` to the module's logical addresses. The module passes 80/20 weights and cannot enable or verify the load-balancing switch. The weights express intent, not guaranteed request percentages.

Health-check routing and automatic failover have no corresponding fields/resources in the verified provider schema. A CNAME pointing to a service is ordinary CNAME, not Route53 alias or health-aware routing. These scenarios remain deferred.

```shell
terraform destroy -var-file=terraform.tfvars
```

Create mode removes owned records and the zone; existing mode removes only owned records. Confirm API absence after cleanup and account for DNS TTL. External load-balancing settings and external records remain caller-owned. On 2026-11-05, Terraform 1.5.7 and online provider 0.0.73 passed plan/apply, all nine records' API read-back, a normal second no-change plan and standard destroy with deletion confirmation for all ten resources. Both assigned authoritative servers returned the expected configured answers; public resolution did not pass because registrar delegation remained unchanged. Mobile-client routing behavior, weighted behavior and failover remain unverified.
