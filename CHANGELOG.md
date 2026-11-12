# Changelog

## Unreleased

- Sequence the complete example's AAAA record after other records to mitigate concurrent DNS writes; preserve outputs and migrate existing AAAA state with a moved block.

- Draft public DNS zone and keyed-record module with basic and complete examples.
- Explicit external-zone ownership and externally enabled weighted-routing boundary.
- Bilingual documentation and basic/complete examples.
- Terraform 1.5.7 with online provider 0.0.73 passed creation, no-change refresh plans and standard destruction for both examples; public DNS acceptance remains incomplete because registrar delegation was unchanged.
- Health-check failover and Route53 alias targets deferred due to provider schema gaps.
