# Basic public DNS

Create a public zone for your registered domain and one `www` A record. This example owns the zone and record; the registrar and website remain caller-owned.

The module source is `terraform-volcenginecc-modules/dns/volcenginecc`. It is an unpublished draft; Registry installation is not verified. Static validation uses a temporary local source. Validation targets are Terraform 1.5.7 and OpenTofu 1.11.8, with provider 0.0.60 and 0.0.73.

Provide `zone_name` and `website_ipv4` in a private variable file. Set provider credentials through your credential manager and select `region` if needed. Use your actual registered domain and website IP; there are no default domain or IP values.

```shell
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
terraform output name_servers
terraform output zone_status
terraform plan -var-file=terraform.tfvars
```

Configure every assigned name server at the registrar, complete any ownership verification, and confirm public `www` resolution. `cache_stage=0` reports ownership, `is_ns_correct=true` reports correct delegation, and `stage=0` reports normal zone status. These are provider indicators, not an independent DNS test. Require the second plan to show no changes.

Clean up with the same engine, configuration and state:

```shell
terraform destroy -var-file=terraform.tfvars
```

Query DNS zone and record APIs to confirm removal; DNS caches may retain answers until TTL expires. On 2026-11-05, Terraform 1.5.7 and online provider 0.0.73 passed plan/apply, API read-back, a normal second no-change plan and standard destroy with deletion confirmation for both resources. Public resolution did not pass because registrar delegation remained unchanged. This example has no health-check failover, weighted routing or Route53 alias configuration.
