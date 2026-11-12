# COMPLETE 公网 DNS 示例

## 1. 概述

本示例配置网站 IPv4/IPv6、CNAME、邮件 A/MX、SPF TXT、禁用 TXT，以及带默认兜底的 API 线路路由。可创建带项目和标签的区域，或管理已有区域的记录；可选加权配置使用外部启用的负载均衡。调用方准备域名、服务地址、允许的线路代码及 NS 配置权限，相比 basic 覆盖更多记录类型和路由场景。

## 2. 用法

使用 Terraform 1.5.7，在 `examples/complete` 目录运行。通过运行环境设置 `VOLCENGINE_ACCESS_KEY` 和 `VOLCENGINE_SECRET_KEY`，账号需具备对应区域和记录的管理权限。

Apply 和 Destroy 均使用 `-parallelism=1`，将本次执行的所有资源操作串行化；`depends_on` 负责两次 Module 调用的先后顺序。并发度通过执行参数设置，不作为 Module 输入变量。

1. 编辑本目录的 `terraform.tfvars`。以下域名和地址用于展示格式，替换为你的已注册域名及真实服务地址；`routing_line` 从 ListLines/ListCustomLines 选择，需符合域名功能版本，且不能为 `"default"`。

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

   `existing_zone_id=null` 时创建区域，附带 `project_name`、`DNS complete` 备注及 `Environment=development`、`ManagedBy=Terraform` 标签。使用已有区域时填入其实际 ID，`zone_name` 仍必填，且必须与该区域域名一致；区域项目、备注和标签不会传递给 Module。首次 Apply 前确定模式，并检查已有记录是否冲突。

2. 初始化并检查首次计划。默认新建模式预期新增一个区域和九条记录；已有区域模式预期仅新增九条记录。

   ```shell
   terraform init
   terraform plan
   ```

3. 创建资源并查看输出。`module.dns` 管理区域和其他记录，`module.dns_ipv6` 在前者完成后创建 AAAA，记录输出合并两次调用。

   ```shell
   terraform apply -parallelism=1
   terraform output
   ```

   新建模式在注册商配置 `name_servers`，或在父区域配置子域 NS 委派，并完成必要的所有权验证。已有模式的 `name_servers`、`zone_status` 为 `null`，由调用方检查区域的所有权和委派。域名应已注册，NS 配置正确且状态正常。

   委派生效后，通过普通递归 DNS 确认根域 A/AAAA、`www` CNAME、`mail` A、优先级为 10 的 MX 和 SPF TXT；启用记录的业务 TTL 为 600 秒，`maintenance` 不返回 TXT。对 API 使用匹配所选线路的客户端查询，同时使用其他来源确认默认线路兜底。来源路由不检查服务健康。

4. 配置稳定后再次检查计划，预期无变化。

   ```shell
   terraform plan
   ```

5. 确认删除范围后清理。依赖关系使 AAAA 先删除，再删除其他记录及本配置创建的区域。

   ```shell
   terraform destroy -parallelism=1
   ```

可选加权配置只用于已有区域。先在外部为 `weighted/A/default` 准备记录集并启用负载均衡，然后设置 `enable_weighted_routing_example=true`，使用不同的 `website_ipv4` 和 `regional_api_ipv4`。该分支新增 `weighted_primary`、`weighted_secondary` 两个逻辑记录，权重分别为 80 和 20。已有值分别使用 `ZID|RecordID` 导入 `module.dns.volcenginecc_dns_record.this["weighted_primary"]` 和 `module.dns.volcenginecc_dns_record.this["weighted_secondary"]`，再检查 Plan 并 Apply，避免重复创建。Module 不启用或检查外部负载均衡开关。

## 3. 依赖要求

| 名称 | 版本 |
|---|---|
| Terraform | `>= 1.5.7, < 1.12.0` |
| `volcengine/volcenginecc` | `>= 0.0.60` |

操作步骤使用 Terraform 1.5.7。

## 4. Providers

| 名称 | 来源 |
|---|---|
| `volcenginecc` | `registry.terraform.io/volcengine/volcenginecc` |

两次 Module 调用共用本目录配置的 Provider，不使用 alias。

## 5. 资源

| 名称 | 说明 |
|---|---|
| `module.dns` | 使用 `source = "terraform-volcenginecc-modules/dns/volcenginecc"` 和 `version = "~> 1.0"`；按模式创建区域或使用已有区域，管理八条基础记录及可选的两条加权记录。 |
| `module.dns_ipv6` | 使用 `source = "terraform-volcenginecc-modules/dns/volcenginecc"` 和 `version = "~> 1.0"`；依赖 `module.dns`，通过其 `zone_id` 管理一条根域 AAAA。 |

本 example root 不直接声明 Resource 或 Data Source。

## 6. 输入

| 名称 | 说明 |
|---|---|
| `region` | Provider 地域，默认 `"cn-beijing"`。 |
| `zone_name` | 必填、无默认值；已注册且可管理的域名，也用于 CNAME 和 MX 目标；已有模式下必须与 `existing_zone_id` 对应的域名一致。 |
| `existing_zone_id` | 可选，默认 `null`；为 `null` 时创建区域，指定非空区域 ID 时仅管理该区域的记录。首次 Apply 前选择模式。 |
| `project_name` | 新建区域所属项目，默认 `"default"`；已有区域模式不使用该值。 |
| `website_ipv4` | 必填、无默认值；根域 A 和默认 API 路由地址，也用于可选加权主记录。 |
| `website_ipv6` | 必填、无默认值；根域 AAAA 地址，由 `dns_ipv6` 管理。 |
| `mail_ipv4` | 必填、无默认值；`mail` A 地址，根域 MX 指向 `mail.zone_name`。 |
| `regional_api_ipv4` | 必填、无默认值；非默认 API 线路地址，也用于可选加权次记录；启用加权时与主记录地址不同。 |
| `routing_line` | 必填、无默认值；域名功能版本允许的非默认线路代码，不能为空白或 `"default"`。 |
| `enable_weighted_routing_example` | 默认 `false`；设为 `true` 时必须使用已有区域，并先在外部启用 `weighted/A/default` 负载均衡。 |

## 7. 输出

| 名称 | 说明 |
|---|---|
| `zone_id` | 新建区域 ZID 或传入的已有区域 ID。 |
| `name_servers` | 新建区域分配的权威服务器；已有区域模式为 `null`，需从区域管理方获取。 |
| `zone_status` | 新建区域的运行状态、账号归属及 NS 配置状态；已有区域模式为 `null`。 |
| `record_ids` | 合并两次调用的 RecordID 映射，包括 `ipv6`；加权启用时增加两个加权键。 |
| `record_set_ids` | 合并两次调用的只读 RecordSetID 映射，用于定位记录集，不接管其负载均衡设置。 |
| `records` | 合并两次调用的主机名、类型、TTL、线路、启停和权重，便于核对记录配置；返回权重不能用于判断加权开关是否启用。 |

## 8. 示例

本目录即为 complete 示例，适用于多类型解析、邮件配置、来源线路路由或已有区域记录管理。默认配置包含九条记录，可选加权分支增加两条记录；basic 只创建区域和一条网站 A 记录。

## 9. 说明

- Apply 和 Destroy 的并发度设为 1，使用 `terraform apply -parallelism=1` 和 `terraform destroy -parallelism=1` 串行执行所有资源操作。`depends_on` 负责两次 Module 调用的先后顺序，并发度通过运行命令设置。
- 凭据通过 Provider 支持的运行环境传入，不写入源码或 `terraform.tfvars`。
- Apply 后再次执行 `terraform plan`，只有结果无变化时才满足幂等要求。
- 新建模式的 Destroy 删除本配置创建的区域和记录；已有模式保留区域，只删除本配置管理的记录。外部负载均衡开关和其他记录由其原管理方维护；本配置导入接管的记录也会被删除。
- `zone_name` 与已有区域 ID 的对应关系由调用方确认。NS 和账号归属状态正确后，还需通过普通递归 DNS 检查公网答案；仅直查权威服务器无法确认注册商委派。
- 升级包含旧 AAAA 地址的配置时，保留现有 `moved` 声明：`module.dns.volcenginecc_dns_record.this["ipv6"]` 迁移到 `module.dns_ipv6.volcenginecc_dns_record.this["ipv6"]`。检查 Plan，确认未修改的记录只迁移地址。
- 80/20 权重是记录配置，实际请求比例受 DNS 缓存和客户端行为影响。默认线路是来源兜底，不是基于健康状态的故障转移。
- 删除自建区域前迁移仍需保留的业务解析；记录修改或删除后，递归 DNS 可能在原 TTL 到期前继续返回缓存。
