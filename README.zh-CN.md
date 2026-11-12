# terraform-volcenginecc-dns

基于 VolcengineCC 管理公网 DNS 托管区域和单条解析记录的 Terraform 模块，明确区分线路路由与需外部启用的加权路由。

## 1. 概述（Overview）

创建一个 `volcenginecc_dns_zone`，通过稳定逻辑名称管理解析记录；也可传入调用方拥有的区域 ID，仅管理记录。每个 map 条目拥有一条单独记录，云端记录集 ID 仅作为只读输出。域名注册、所有权验证、注册商 NS 委派、服务端点及记录集负载均衡设置由调用方负责。

可配置 A、AAAA、CNAME、MX、TXT、NS、SRV。可使用默认线路及功能版本允许的线路路由。已核对的 Provider Schema 中，没有健康检查故障转移或 Route53 别名目标对应的 DNS 字段或资源。CNAME 是普通 DNS 记录，遵循其正常限制。

## 2. 用法（Usage）

Registry 地址用于后续发布；当前 draft 没有已发布模块版本，尚未验证 Registry 消费。静态验证仅在临时副本中重写 source。

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

Provider 认证和地域由调用方配置。通过凭据管理工具设置 `VOLCENGINE_ACCESS_KEY` 和 `VOLCENGINE_SECRET_KEY`。

```hcl
provider "volcenginecc" {
  region = "cn-beijing"
}
```

创建后在注册商配置全部 `name_servers`；子域名在父区域配置委派。必要时完成所有权验证，并检查 `zone_status`。仅创建区域不会自动建立公网 DNS 委派。

## 3. 示例（Examples）

- `examples/basic`：一个已注册域名、一条网站 A 记录和分配的 NameServer 输出。
- `examples/complete`：A/AAAA/CNAME/MX/TXT、多记录集、显式 TTL、记录启停、区域项目和标签，以及带默认兜底的非默认 API 线路。需提供域名功能版本允许的线路代码。
- complete 使用第二次模块调用，让 AAAA 依赖其他记录完成，以缓解并发写入的 `ErrDBDeadlock`；输出保留全部逻辑 key，`moved` 声明迁移已有 AAAA State 地址。其他记录仍并发写入，本次改动尚未通过真实 API 复验。
- complete 可选加权场景在已有区域配置两个权重为 80/20 的 A 记录值。需先在外部对准确的 `weighted`/`A`/`default` 记录集启用负载均衡；模块不能启用或检查该开关。已有加权记录必须 import，或从本模块配置中排除，避免重复创建。
- 健康检查故障转移和别名场景推迟到 Provider 提供对应生命周期及配置后实现。当前不宣称存在可运行的故障转移示例。

## 4. 版本要求（Requirements）

| 名称 | 版本 / 前提 |
|---|---|
| Terraform | 静态验证通过：`1.5.7` |
| OpenTofu | 静态验证通过：`1.11.8` |
| 共用引擎约束 | `>= 1.5.7, < 1.12.0`；未逐一验证区间内其他版本 |
| Provider 最低版本 | `0.0.60`；其 Schema 已包含区域及全部所用记录字段 |
| Provider 当前已验证版本 | `0.0.73`，发布于 2026-10-26 |
| 域名 | 已注册公网域名，并具有管理 DNS 和修改委派的权限 |
| 高级路由 | 域名功能版本允许所用线路代码、TTL 和权重 |

当前状态：**draft**，因为加权路由依赖外部配置，故障转移和别名能力尚待实现。静态验证不代表公网解析已生效或已具备生产可用性。

2026-11-05，两种引擎搭配 Provider 0.0.60 和 0.0.73，均通过根模块、basic、complete 和生命周期 fixture 的 fmt/init/validate/静态 Plan，以及可选既有区域加权配置和 15 项负例 Plan。双语文档与 Shell 语法检查通过。ShellCheck、TFLint 和 terraform-docs 不可用，未执行。

## 5. Providers（Providers）

| 名称 | 来源 | 约束 |
|---|---|---|
| `volcenginecc` | `registry.terraform.io/volcengine/volcenginecc` | `>= 0.0.60` |

## 6. 资源（Resources）

| 模式 | 类型 | 地址 / 职责 |
|---|---|---|
| 创建 | [volcenginecc_dns_zone](https://registry.terraform.io/providers/volcengine/volcenginecc/0.0.73/docs/resources/dns_zone) | `volcenginecc_dns_zone.this[0]`：拥有一个区域 |
| 两种模式 | [volcenginecc_dns_record](https://registry.terraform.io/providers/volcengine/volcenginecc/0.0.73/docs/resources/dns_record) | `volcenginecc_dns_record.this[key]`：拥有单条记录 |

未使用 Data Source。外部区域通过 ID 传入，模块不查询或销毁该区域。

## 7. 输入（Inputs）

| 名称 | 类型 | 默认值 | 必填条件 / 说明 |
|---|---|---|---|
| `create_zone` | `bool` | `true` | 首次 apply 前确定归属模式 |
| `zone_name` | `string` | `null` | 创建模式必填；小写 ASCII/punycode 域名，不带末尾点 |
| `existing_zone_id` | `string` | `null` | 既有模式必填；区域由调用方拥有 |
| `project_name` | `string` | `null` | 新建区域所属项目；既有模式不可设置 |
| `zone_remark` | `string` | `null` | 新建区域备注；既有模式不可设置 |
| `tags` | `set(object({key=string,value=string}))` | `null` | 新建区域标签；必须显式提供值，key 非空且唯一；拒绝空集合 |
| `acknowledge_external_weighted_routing` | `bool` | `false` | 既有模式显式设置权重时必须为 true；外部开关仍由调用方拥有 |
| `records` | `map(object(...))` | 无 | 必填，可为空；稳定 key 拥有单条记录 |
| `records.host` | `string` | 无 | 必填相对前缀；`@` 表示根域；不要传完整区域名称 |
| `records.type` | `string` | 无 | 必填大写 A/AAAA/CNAME/MX/TXT/NS/SRV |
| `records.value` | `string` | 无 | 必填；MX 如 `10 mail.domain`，优先级 1-99；TXT 原样传递 |
| `records.ttl` | `number` | `600` | 正整数秒；必须满足功能版本限制 |
| `records.line` | `string` | `"default"` | 域名功能版本允许的线路代码 |
| `records.remark` | `string` | `""` | UTF-8 备注，不超过 16 个字符 |
| `records.enable` | `bool` | `true` | 是否启用该单条记录 |
| `records.weight` | `number` | `null` | A/AAAA/CNAME 可选非负整数；受功能版本及外部负载均衡开关约束 |

同一 host/type/line 组内必须使用相同 TTL，且统一设置或省略权重。拒绝重复 host/type/line/value，以及同 host/line 下 CNAME 与其他类型共存。这些检查仅覆盖本模块声明的记录；调用方需检查已有记录的额外冲突。

## 8. 输出（Outputs）

| 名称 | 类型 | 含义 / 空值 |
|---|---|---|
| `zone_id` | `string` | 新建区域 ZID 或传入的既有 ID |
| `name_servers` | `set(string)` | 分配的权威服务器；既有模式为 `null` |
| `zone_status` | `object({stage=number,cache_stage=number,is_ns_correct=bool})` | Provider 状态及所有权、委派指标；既有模式为 `null` |
| `record_ids` | `map(string)` | 按逻辑 key 输出云端 RecordID；无记录为 `{}` |
| `record_set_ids` | `map(string)` | 云端 RecordSetID；非 A/AAAA/CNAME 的值可能为 `null`；不拥有记录集设置 |
| `records` | `map(object({pqdn=string,type=string,ttl=number,line=string,enable=bool,weight=number}))` | 按 key 输出 Provider 回读；无记录为 `{}` |

不输出记录值，但记录值仍会进入 Terraform State 和 Plan。请按业务需要保护 TXT 验证值和 State。

## 9. 其他说明（Notes）

- 不要原地切换 `create_zone`。创建模式拥有区域及配置的记录，destroy 删除这些资源；既有模式仅拥有声明的记录，保留外部区域。
- 修改 `zone_name` 会替换区域；两种已测试 Provider 中，修改记录 `value` 或 `host` 的 Plan 为原地更新。这些结果来自合成 State，不代表真实云 State。修改记录逻辑 key 会删除并新建记录；其他字段及 ID 变更应检查固定版本 Plan。
- 使用 `zid` 将区域 import 到 `module.dns.volcenginecc_dns_zone.this[0]`；使用 `zid|record_id` 将记录 import 到 `module.dns.volcenginecc_dns_record.this["key"]`。确保配置匹配，先检查 Plan 再 apply。模块不自动接管或发现已有资源。
- `project_name`、`zone_remark`、`tags` 及可选记录属性对应 Optional+Computed 字段。区域属性为 null 表示未指定；将已设置的值改为 null 是否清除，尚未证明。标签移除和空备注仍未验证；配置的区域标签、禁用记录回读及二次 Plan 无变更已通过真实验证。
- 记录集负载均衡使用 [UpdateRecordSet](https://www.volcengine.com/docs/6758/155111)，当前已验证 DNS 资源 Schema 不包含该能力。`weight` 回读不能证明加权解析生效；确认变量只是调用方声明，不是 API 检查。
- `record_set_id`、所有权、NameServer 和状态均为 Computed-only；不管理付费功能版本、续费、健康检查、GTM 锁和别名目标。未引入轮询或命令/SDK 生命周期绕过。
- [CreateRecord](https://www.volcengine.com/docs/6758/155104) 和[记录类型格式](https://www.volcengine.com/docs/6758/145121)定义公网 DNS 语义。AWS Route53 zone/record 和阿里云 DNS domain/record 示例仅用于场景参考，字段不可互换。
- 工程规范来源：飞书文档 `C3TZdz2lnoAZmDxC7zRcOSgzn4d`，revision 2645，5.3/5.5 节及场景 54，读取日期 2026-11-05。未找到本地 PRD/规范文件，使用用户场景及权威场景条目。
- 2026-11-05，使用 Terraform 1.5.7 与线上 Provider 0.0.73，basic 和 complete 均通过真实 Plan/Apply、独立 API 回读、正常刷新后二次 Plan 无变更，以及标准 Destroy 和独立删除确认。basic 创建并删除 2 个资源，complete 创建并删除 10 个。测试域名仍委派至原 DNS 服务商，公网解析未通过；complete 在两个分配的权威服务器上查询通过。移动客户端线路行为、加权行为、更新操作及 Registry 发布仍未验证。下次公网解析复验需先重建区域和记录，再安排委派。
