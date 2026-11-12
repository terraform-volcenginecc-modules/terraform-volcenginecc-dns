# terraform-volcenginecc-dns

Terraform module for public DNS zones and individual records using VolcengineCC, with explicit boundaries for line routing and externally enabled weighted routing.

Module source: `terraform-volcenginecc-modules/dns/volcenginecc`; module version: `version = "~> 1.0"` (>= 1.0.0, < 2.0.0). Provider version requirements are separate. Registry installation requires a published module release in this range.

## 1. Overview

Create one `volcenginecc_dns_zone` and manage records keyed by stable logical names, or manage records in a caller-owned zone by ID. Each map entry owns one individual record; cloud record-set IDs are read-only outputs. The caller owns domain registration, ownership verification, registrar delegation, service endpoints and any record-set load-balancing settings.

Supports A, AAAA, CNAME, MX, TXT, NS and SRV configuration. Default and edition-permitted line routing are available. Health-check failover and Route53 alias targets have no corresponding DNS fields/resources in the verified provider schema. CNAME is an ordinary DNS record with its normal restrictions.

## 2. Usage

The Registry address is reserved for publication; this draft has no published module version and Registry consumption has not been verified. Local validation rewrites the source only in temporary copies.

```hcl
module "dns" {
  source  = "terraform-volcenginecc-modules/dns/volcenginecc"
  version = "~> 1.0"

  zone_name = var.registered_domain
  records = {
    website = {
      host  = "www"
      type  = "A"
      value = var.website_ipv4
    }
  }
}
```

Provider authentication and region belong to the caller. Set `VOLCENGINE_ACCESS_KEY` and `VOLCENGINE_SECRET_KEY` through your credential manager.

```hcl
provider "volcenginecc" {
  region = "cn-beijing"
}
```

After creation, configure all `name_servers` at the registrar (or delegate a subdomain at its parent), complete ownership verification if necessary, and check `zone_status`. Creating a zone alone does not establish public DNS delegation.

## 3. Examples

- `examples/basic`: one registered domain, one website A record and assigned name-server outputs.
- `examples/complete`: A/AAAA/CNAME/MX/TXT records, explicit TTL, enabled/disabled records, zone project/tags and a non-default API line with a default fallback. Supply a line code allowed by the domain's edition.
- In complete, AAAA depends on completion of the other records through a second module call to mitigate concurrent-write `ErrDBDeadlock`; outputs retain all logical keys and a `moved` block preserves the existing AAAA state address. Other record writes remain concurrent. This change has not yet been validated against the live API.
- The optional complete weighted scenario configures two A values with 80/20 weights in an existing zone. First enable load balancing externally for the exact `weighted`/`A`/`default` record set; the module cannot enable or check that switch. Existing weighted records must be imported or omitted from this module's configuration to avoid duplicate creation.
- Health-check failover and alias scenarios are deferred until the provider exposes their lifecycle and configuration. No runnable failover example is claimed.

## 4. Requirements

| Name | Version / prerequisite |
|---|---|
| Terraform | Statically verified: `1.5.7` |
| OpenTofu | Statically verified: `1.11.8` |
| Shared engine constraint | `>= 1.5.7, < 1.12.0`; other versions in this range are not individually verified |
| Provider minimum | `0.0.60`; DNS zone and all used record fields exist in its schema |
| Provider current verified version | `0.0.73`, released 2026-10-26 |
| Domain | Registered public domain, permission to manage DNS and change delegation |
| Advanced routing | DNS edition permitting requested line codes, TTL and weights |

Current status: **draft** because weighted routing requires external settings and failover/alias capabilities are deferred. Static validation does not establish successful public resolution or production readiness.

On 2026-11-05, both engines passed fmt/init/validate/static plan with providers 0.0.60 and 0.0.73 for the root, basic, complete and lifecycle fixture, the optional external-zone weighted configuration, and 15 negative plans. Bilingual documentation and shell syntax checks passed. ShellCheck, TFLint and terraform-docs were unavailable and were not run.

## 5. Providers

| Name | Source | Constraint |
|---|---|---|
| `volcenginecc` | `registry.terraform.io/volcengine/volcenginecc` | `>= 0.0.60` |

## 6. Resources

| Mode | Type | Address / responsibility |
|---|---|---|
| Create | [volcenginecc_dns_zone](https://registry.terraform.io/providers/volcengine/volcenginecc/0.0.73/docs/resources/dns_zone) | `volcenginecc_dns_zone.this[0]`: own one zone |
| Both | [volcenginecc_dns_record](https://registry.terraform.io/providers/volcengine/volcenginecc/0.0.73/docs/resources/dns_record) | `volcenginecc_dns_record.this[key]`: own individual records |

There are no data sources. External zones are passed by ID and are not queried or destroyed.

## 7. Inputs

| Name | Type | Default | Required / description |
|---|---|---|---|
| `create_zone` | `bool` | `true` | Choose ownership before first apply |
| `zone_name` | `string` | `null` | Required in create mode; lowercase ASCII/punycode domain without trailing dot |
| `existing_zone_id` | `string` | `null` | Required in existing mode; zone must be caller-owned |
| `project_name` | `string` | `null` | Created-zone project; unavailable in existing mode |
| `zone_remark` | `string` | `null` | Created-zone remark; unavailable in existing mode |
| `tags` | `set(object({key=string,value=string}))` | `null` | Created-zone tags; explicit values and unique nonempty keys; empty set rejected |
| `acknowledge_external_weighted_routing` | `bool` | `false` | Required true for explicit weights in existing mode; external switch remains caller-owned |
| `records` | `map(object(...))` | none | Required, possibly empty; stable keys own individual records |
| `records.host` | `string` | none | Required relative prefix; `@` for apex; do not pass full zone name |
| `records.type` | `string` | none | Required uppercase A/AAAA/CNAME/MX/TXT/NS/SRV |
| `records.value` | `string` | none | Required; MX uses `10 mail.domain`; priority 1-99; TXT passed unchanged |
| `records.ttl` | `number` | `600` | Positive integer seconds; must satisfy edition limits |
| `records.line` | `string` | `"default"` | Line code permitted by the domain edition |
| `records.remark` | `string` | `""` | UTF-8 remark, at most 16 characters |
| `records.enable` | `bool` | `true` | Whether this individual record is enabled |
| `records.weight` | `number` | `null` | Optional nonnegative integer for A/AAAA/CNAME, subject to edition limits and external load balancing |

Records in a host/type/line group must share TTL and consistently specify or omit weights. Duplicate host/type/line/value tuples and CNAME coexistence with other types at the same host/line are rejected. These checks cover records declared in this module; the caller must inspect existing records for additional conflicts.

## 8. Outputs

| Name | Type | Meaning / empty values |
|---|---|---|
| `zone_id` | `string` | Created ZID or supplied existing ID |
| `name_servers` | `set(string)` | Assigned authoritative servers; `null` in existing mode |
| `zone_status` | `object({stage=number,cache_stage=number,is_ns_correct=bool})` | Provider status and ownership/delegation indicators; `null` in existing mode |
| `record_ids` | `map(string)` | Cloud RecordID by logical key; `{}` with no records |
| `record_set_ids` | `map(string)` | Cloud RecordSetID; individual values may be `null` outside A/AAAA/CNAME; no settings ownership |
| `records` | `map(object({pqdn=string,type=string,ttl=number,line=string,enable=bool,weight=number}))` | Provider read-back by key; `{}` with no records |

Record values are not output, but remain in Terraform state and plans. Treat TXT verification values and state as appropriate for your application.

## 9. Notes

- Do not switch `create_zone` in place. Create mode owns the zone and its configured records; destroy removes those resources. Existing mode owns only the declared records and preserves the external zone.
- Changing `zone_name` replaces the zone; changing record `value` or `host` plans an in-place update with both tested providers. These results come from synthetic state, not real cloud state. Changing logical record keys causes deletion/creation; consult the pinned plan for other fields and ID changes.
- Import a zone to `module.dns.volcenginecc_dns_zone.this[0]` using `zid`; import each record to `module.dns.volcenginecc_dns_record.this["key"]` using `zid|record_id`. Ensure configuration matches and review a plan before applying. No automatic adoption or discovery occurs.
- `project_name`, `zone_remark`, `tags` and optional record attributes use Optional+Computed provider fields. Null zone attributes leave configuration unspecified; clearing a previously specified value by changing to null is not proven. Tag removal and empty remarks remain unverified; configured zone tags, disabled-record read-back and second no-change plans passed real validation.
- Record-set load balancing uses [UpdateRecordSet](https://www.volcengine.com/docs/6758/155111), which is absent from the verified DNS resource schema. `weight` read-back is not proof that weighted resolution works. The acknowledgement is a caller assertion, not an API check.
- `record_set_id`, ownership, name servers and status are Computed-only; paid DNS edition, renewal, health checks, GTM locks and alias targets are not managed. No polling or command/SDK lifecycle bypass is included.
- [CreateRecord](https://www.volcengine.com/docs/6758/155104) and [record type formats](https://www.volcengine.com/docs/6758/145121) define public DNS semantics. AWS Route53 zone/record and Alibaba DNS domain/record examples inform scenarios only; their schemas are not interchangeable.
- Engineering standard: Lark document `C3TZdz2lnoAZmDxC7zRcOSgzn4d`, revision 2645, sections 5.3/5.5 and scene 54, read 2026-11-05. No local PRD/standard files were available; the user scenario and authoritative scene were used.
- On 2026-11-05, basic and complete passed real plan/apply, independent API read-back, normal second plans with no changes and standard destroy with independent deletion confirmation using Terraform 1.5.7 and the online provider 0.0.73. Basic created and removed 2 resources; complete created and removed 10. Public resolution did not pass because the test domain remained delegated to its previous DNS provider, although complete answers from both assigned authoritative servers passed. Mobile-client routing behavior, weighted behavior, updates and Registry publication remain unverified. Recreate the zone and records before arranging delegation for another public-resolution test.
