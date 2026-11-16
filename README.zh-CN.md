# terraform-volcenginecc-dns

使用 VolcengineCC 管理公网 DNS 区域和单条解析记录，支持线路路由及由调用方启用的加权路由。

## 1. 概述（Overview）

本 Module 可创建公网 DNS 区域并管理其中的 A、AAAA、CNAME、MX、TXT、NS、SRV 记录，也可通过已有区域 ID 仅管理记录。记录以稳定的逻辑名称标识，通过区域 ID 关联托管区域。域名注册、所有权验证、NS 委派、服务端点和记录集负载均衡设置由调用方管理。

## 2. 用法（Usage）

准备已注册且可管理的域名、服务地址，以及具有 DNS 区域和记录管理权限的火山引擎账号。使用 Terraform 1.5.7，在调用方项目配置 Provider，并通过运行环境设置 `VOLCENGINE_ACCESS_KEY` 和 `VOLCENGINE_SECRET_KEY`。

以下 `example.com` 和 `192.0.2.10` 用于展示配置格式，使用时替换为你的域名和网站 IPv4 地址：

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

默认 `create_zone=true`，配置会创建一个区域和一条 `www` A 记录。接入已有区域时，设置 `create_zone=false` 和 `existing_zone_id`，并将 `zone_name`、`project_name`、`zone_remark`、`tags` 保持为 `null`；该模式只管理 `records` 中声明的记录，不查询或接管已有区域。

在调用方项目目录执行。Apply 和 Destroy 均使用 `-parallelism=1`，将本次 Terraform 执行的资源操作串行化。并发度通过执行参数设置，不作为 Module 输入变量。

```shell
terraform init
terraform plan
terraform apply -parallelism=1
```

新建区域后，将全部 `name_servers` 配置到注册商；使用子域名区域时，在父区域建立对应的 NS 委派。若云解析要求找回域名，先完成所有权验证。`zone_status.cache_stage=0` 表示当前账号可管理域名，`is_ns_correct=true` 表示 NS 配置正确，`stage=0` 表示区域正常。账号归属状态不等于域名已经注册或完成委派。

完成委派后，用普通递归 DNS 查询实际业务域名，确认记录值正确；仅显式查询分配的权威服务器，不能确认公网委派已经生效。确认不再需要资源时再执行销毁：

```shell
terraform plan
terraform destroy -parallelism=1
```

Apply 后的第二次 Plan 应显示无变化。销毁前确认区域和记录的归属，并迁移仍需保留的业务解析。

## 3. 示例（Examples）

- basic：在 `examples/basic` 执行，为已注册域名创建区域和一条网站 A 记录，输出区域 ID、NameServer、区域状态和记录 ID。调用方准备域名、网站 IPv4 地址及注册商配置权限。
- complete：在 `examples/complete` 执行，配置 A、AAAA、CNAME、MX、SPF TXT、禁用 TXT，以及具有默认兜底的非默认 API 线路。可创建带项目和标签的区域，或仅管理已有区域的记录；AAAA 通过独立的 `dns_ipv6` 调用在其他记录完成后创建。可选 80/20 加权场景需要已有区域和外部启用的记录集负载均衡。

## 4. 版本要求（Requirements）

| 名称 | 版本 |
|---|---|
| Terraform | `>= 1.5.7, < 1.12.0` |
| `volcengine/volcenginecc` | `>= 0.0.60` |

操作步骤使用 Terraform 1.5.7。Module 的 `version = "~> 1.0"` 约束与 Provider 版本约束分别配置。

## 5. Providers（Providers）

| 名称 | 来源 |
|---|---|
| `volcenginecc` | `registry.terraform.io/volcengine/volcenginecc` |

Provider 的地域和认证由调用方配置；本 Module 不声明 Provider alias。

## 6. 资源（Resources）

| 模式 | 类型 | 名称 |
|---|---|---|
| 创建区域，`create_zone=true` | Resource：`volcenginecc_dns_zone` | [`volcenginecc_dns_zone.this[0]`](https://registry.terraform.io/providers/volcengine/volcenginecc/latest/docs/resources/dns_zone) |
| 创建区域或使用已有区域 | Resource：`volcenginecc_dns_record` | [`volcenginecc_dns_record.this[key]`](https://registry.terraform.io/providers/volcengine/volcenginecc/latest/docs/resources/dns_record) |

区域资源最多创建一个实例，记录实例数由 `records` 的条目数决定。每个条目管理一条单独记录，即使云端将多条记录归入同一记录集。本 Module 不声明 Data Source。

## 7. 输入（Inputs）

| 名称 | 类型 | 默认值 | 创建模式下是否必填 | 说明 |
|---|---|---|---|---|
| `create_zone` | `bool` | `true` | 否 | 是否创建并管理区域；不接受 `null`。首次 Apply 前确定归属模式。 |
| `zone_name` | `string` | `null` | 是 | 已注册公网域名，小写 ASCII 或 punycode，总长度不超过 253，标签格式合法且不带末尾点；已有区域模式保持 `null`。 |
| `existing_zone_id` | `string` | `null` | 否 | 已有区域模式必填，去除首尾空白后不能为空；创建模式保持 `null`。已有区域仍由调用方管理。 |
| `project_name` | `string` | `null` | 否 | 新建区域所属项目；指定时不能为空白字符串。`null` 使用 Provider 默认行为；已有区域模式保持 `null`。 |
| `zone_remark` | `string` | `null` | 否 | 新建区域备注；`null` 表示未指定。已有区域模式保持 `null`。 |
| `tags` | `set(object({key=string,value=string}))` | `null` | 否 | 新建区域标签；指定时集合非空，键唯一且不为空白，值必须显式提供且不能为 `null`，可为空字符串。已有区域模式保持 `null`。 |
| `acknowledge_external_weighted_routing` | `bool` | `false` | 否 | 不接受 `null`。显式设置记录权重时，在已有区域模式设为 `true`，确认所有受影响记录集已在外部启用负载均衡；该变量不启用或检查开关。 |
| `records` | `map(object)`，结构如下 | 无 | 是 | 以稳定逻辑名称为键的记录集合；不接受 `null`，可为 `{}`。两种模式均必填，键不能全为空白。 |
| `records.host` | `string` | 无 | 每条记录必填 | 相对主机记录，`@` 表示根域名；不能为空白字符串，不使用完整区域名代替主机前缀。 |
| `records.type` | `string` | 无 | 每条记录必填 | 大写类型：`A`、`AAAA`、`CNAME`、`MX`、`TXT`、`NS`、`SRV`。 |
| `records.value` | `string` | 无 | 每条记录必填 | 非空白记录值；A 为 IPv4，AAAA 为 IPv6，MX 为 `优先级 目标域名`，优先级为 1–99，例如 `10 mail.example.com`；其他类型遵循 DNS 格式。 |
| `records.ttl` | `number` | `600` | 否 | 正整数，单位为秒；取值需符合域名功能版本的限制。 |
| `records.line` | `string` | `"default"` | 否 | 非空白线路代码；非默认线路从 ListLines/ListCustomLines 获取，并确认域名功能版本允许使用。 |
| `records.remark` | `string` | `""` | 否 | 单条记录备注，最多 16 个字符。 |
| `records.enable` | `bool` | `true` | 否 | 是否启用该记录；`false` 保留配置但不提供该记录的解析答案。 |
| `records.weight` | `number` | `null` | 否 | 仅 A、AAAA、CNAME 可设置非负整数权重；只能用于已有区域模式，并配合外部负载均衡和确认变量。 |

`records` 的完整对象类型为：

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

同一 `host/type/line` 组内的记录使用相同 TTL，并统一设置或省略权重。不能重复声明同一 `host/type/line/value`，也不能在同一主机和线路上混用 CNAME 与其他类型；主机名比较不区分大小写。这些校验只覆盖本次声明的记录，接入已有区域时还需检查外部记录是否冲突。完整记录值格式可查阅[记录类型格式](https://www.volcengine.com/docs/6758/145121)。

## 8. 输出（Outputs）

| 名称 | 类型 | 说明 |
|---|---|---|
| `zone_id` | `string` | 新建区域的 ZID 或传入的已有区域 ID，可用于关联其他解析配置。 |
| `name_servers` | `set(string)` | 新建区域分配的全部权威服务器，用于注册商或父区域的 NS 委派；已有区域模式为 `null`。 |
| `zone_status` | `object({stage=number,cache_stage=number,is_ns_correct=bool})` | 新建区域的运行状态、账号归属及 NS 配置状态；已有区域模式为 `null`，需由调用方检查。 |
| `record_ids` | `map(string)` | 逻辑名称到云端 RecordID 的映射；没有记录时为 `{}`。 |
| `record_set_ids` | `map(string)` | 逻辑名称到云端 RecordSetID 的只读映射，用于定位记录集；值以 Provider 返回为准，可能为 `null`，不表示 Module 管理记录集设置。 |
| `records` | `map(object({pqdn=string,type=string,ttl=number,line=string,enable=bool,weight=number}))` | 按逻辑名称返回记录的主机名、类型、TTL、线路、启停和权重；没有记录时为 `{}`。其中 `weight` 的返回值不能用于判断负载均衡是否启用。 |

## 9. 其他说明（Notes）

- Apply 和 Destroy 的并发度设为 1，使用 `terraform apply -parallelism=1` 和 `terraform destroy -parallelism=1` 串行执行资源操作。该设置通过运行命令传入。
- 在首次 Apply 前选择区域归属模式。创建模式的 Destroy 删除区域及本配置管理的记录；已有区域模式只删除声明的记录，保留区域。销毁自建区域前，迁移其中仍需保留的业务记录。
- 保持 `records` 的逻辑键稳定。更名或删除键会改变对应记录的资源地址；修改域名、主机、记录值等配置前，检查 Plan 的新增、更新和删除范围，并安排必要的解析切换。
- Module 不自动发现或接管已有记录。接管记录时，将配置与云端记录匹配，并使用 `ZID|RecordID` 导入对应的 `module.dns.volcenginecc_dns_record.this["逻辑名称"]`；创建模式接管已有区域时，使用 ZID 导入 `module.dns.volcenginecc_dns_zone.this[0]`。已有区域模式不导入区域。
- 项目、区域备注和标签为 `null` 时表示未指定；需要移除已有设置时，先检查 Provider 的变更计划和云端结果。
- 加权路由先通过控制台或 [UpdateRecordSet](https://www.volcengine.com/docs/6758/155111) 对准确的主机、类型、线路记录集启用负载均衡。开关由调用方维护，Module 只配置单条记录的权重；权重值不保证实际请求比例。
- 默认线路为来源匹配提供兜底，不检测服务健康。CNAME 是普通 DNS 别名；域名付费功能、续费、健康检查和云资源别名目标不由本 Module 管理。
- 部署后再次执行正常的 `terraform plan`，确认结果无变化，以满足幂等要求。解析修改或删除后，递归 DNS 可能在原 TTL 到期前继续返回缓存答案。
