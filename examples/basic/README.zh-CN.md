# 公网 DNS 基础示例

为已注册域名创建公网区域和一条 `www` A 记录。本示例拥有区域和记录，注册商配置和网站仍由调用方拥有。

模块 source 为 `terraform-volcenginecc-modules/dns/volcenginecc`。当前为未发布 draft，尚未验证 Registry 安装；静态验证使用临时本地 source。验证目标为 Terraform 1.5.7、OpenTofu 1.11.8，以及 Provider 0.0.60 和 0.0.73。

在私有变量文件中提供 `zone_name` 和 `website_ipv4`，通过凭据管理工具设置 Provider 凭据，按需选择 `region`。必须使用实际已注册域名和网站 IP；示例不提供默认域名或 IP。

模块 source 为 `terraform-volcenginecc-modules/dns/volcenginecc`，模块版本约束为 `version = "~> 1.0"`（>= 1.0.0、< 2.0.0），与 Provider 版本要求分别配置。Registry 安装要求该范围内已有已发布模块版本。

```shell
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
terraform output name_servers
terraform output zone_status
terraform plan -var-file=terraform.tfvars
```

在注册商配置全部分配的 NameServer，完成必要的所有权验证，确认公网 `www` 解析。`cache_stage=0` 表示所有权状态，`is_ns_correct=true` 表示委派正确，`stage=0` 表示区域正常。这些是 Provider 指标，不是独立 DNS 测试。二次 Plan 必须无变更。

使用相同引擎、配置和 State 清理：

```shell
terraform destroy -var-file=terraform.tfvars
```

通过区域和记录查询 API 确认移除；DNS 缓存可能在 TTL 到期前保留旧答案。2026-11-05，Terraform 1.5.7 与线上 Provider 0.0.73 已通过真实 Plan/Apply、API 回读、正常刷新后二次 Plan 无变更及标准 Destroy，两个资源均经查询确认删除。注册商委派未改变，公网解析未通过。本示例不配置健康检查故障转移、加权路由或 Route53 别名。
