# BASIC 公网 DNS 示例

## 1. 概述

本示例为已注册域名创建一个公网 DNS 区域和一条 `www` A 记录，输出区域、NameServer 和记录信息。调用方准备域名、网站 IPv4 地址及修改 NS 的权限。相比 complete，本示例只配置最小网站解析，不包含 IPv6、邮件、多线路和加权配置。

## 2. 用法

使用 Terraform 1.5.7，在 `examples/basic` 目录运行。通过运行环境配置 `VOLCENGINE_ACCESS_KEY` 和 `VOLCENGINE_SECRET_KEY`，账号需具备 DNS 区域和记录管理权限。

Apply 和 Destroy 均使用 `-parallelism=1`，将本次执行的资源操作串行化。并发度通过执行参数设置，不作为 Module 输入变量。

1. 编辑本目录的 `terraform.tfvars`。以下域名和 IP 仅展示格式，替换为你可管理的已注册域名和网站公网 IPv4；该域名应由本配置独立管理。

   ```hcl
   region       = "cn-beijing"
   zone_name    = "example.com"
   website_ipv4 = "192.0.2.10"
   ```

2. 初始化并检查首次计划。预期新增一个区域和一条 `www` A 记录。

   ```shell
   terraform init
   terraform plan
   ```

3. 创建资源，并查看分配的 NameServer 和区域状态。

   ```shell
   terraform apply -parallelism=1
   terraform output name_servers
   terraform output zone_status
   ```

   在注册商配置全部 NameServer；使用子域名区域时，在父区域建立 NS 委派。若提示域名待找回，按控制台提示完成所有权验证。确认 `cache_stage=0`、`is_ns_correct=true`、`stage=0`，再通过普通递归 DNS 查询 `www` 的 A 记录，预期返回 `website_ipv4`，业务 TTL 为 600 秒。

4. 配置稳定后再次检查计划，预期无变化。

   ```shell
   terraform plan
   ```

5. 确认不再需要该区域及网站解析后清理资源。

   ```shell
   terraform destroy -parallelism=1
   ```

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

本目录使用 `region` 配置 Provider，不使用 alias。

## 5. 资源

| 名称 | 说明 |
|---|---|
| `module.dns` | 使用 `source = "terraform-volcenginecc-modules/dns/volcenginecc"` 和 `version = "~> 1.0"`，创建区域及一条网站 A 记录。 |

本 example root 不直接声明 Resource 或 Data Source。

## 6. 输入

| 名称 | 说明 |
|---|---|
| `region` | Provider 地域，默认 `"cn-beijing"`。 |
| `zone_name` | 必填、无默认值；已注册且可管理的域名，使用小写 ASCII 或 punycode，不带末尾点；不与其他 Terraform 配置重复管理。 |
| `website_ipv4` | 必填、无默认值；网站公网 IPv4，写入 `www` A 记录。 |

## 7. 输出

| 名称 | 说明 |
|---|---|
| `zone_id` | 新建区域 ZID，可用于定位区域或关联其他解析配置。 |
| `name_servers` | 分配的全部权威 NameServer，需要配置到注册商或父区域。 |
| `zone_status` | `stage`、`cache_stage` 和 `is_ns_correct`，用于检查区域状态、账号归属及 NS 配置。 |
| `record_ids` | 包含 `website` 键及对应云端 RecordID，便于定位网站记录。 |

## 8. 示例

本目录即为 basic 示例，适用于只需要一条网站 IPv4 解析的新建区域。多类型记录、非默认线路和已有区域接入使用 complete 示例。

## 9. 说明

- Apply 和 Destroy 的并发度设为 1，使用 `terraform apply -parallelism=1` 和 `terraform destroy -parallelism=1` 串行执行资源操作。该设置通过运行命令传入。
- 凭据通过 Provider 支持的运行环境传入，不写入源码或 `terraform.tfvars`。
- Apply 后再次执行 `terraform plan`，只有结果无变化时才满足幂等要求。
- 本配置管理新建区域和网站记录；Destroy 会删除两者。域名注册、NS 委派和网站服务器由调用方管理，不随本配置删除。
- 区域创建成功后还要配置 NS 委派。`cache_stage=0` 说明账号可管理该区域，不能单独用它判断公网解析是否生效；使用普通递归 DNS 核对网站答案。
- 销毁区域前迁移仍需保留的解析记录；删除记录后，递归 DNS 可能在原 TTL 到期前继续返回缓存。
