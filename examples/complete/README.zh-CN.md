# 公网 DNS 完整示例

配置网站 IPv4/IPv6、CNAME、邮件 MX/A、SPF TXT、禁用记录和带默认兜底的 API 线路路由。可创建并拥有带项目和标签的区域，也可在首次 apply 前选择调用方拥有的既有区域。

模块 source 为 `terraform-volcenginecc-modules/dns/volcenginecc`。当前 draft 没有已发布模块版本，尚未验证 Registry 安装。验证目标为 Terraform 1.5.7、OpenTofu 1.11.8 和 Provider 0.0.60、0.0.73；本地检查仅在临时副本中重写 source。

提供 `zone_name`、`website_ipv4`、`website_ipv6`、`mail_ipv4`、`regional_api_ipv4` 和 `routing_line`。线路必须来自公网 DNS ListLines/ListCustomLines，且域名功能版本允许使用。默认 API 线路提供兜底，不是基于健康状态的故障转移。既有模式设置 `existing_zone_id`，确认其与 `zone_name` 匹配，并在 apply 前检查或 import 已有记录。不要原地切换归属模式。

凭据和 `region` 由调用方配置，使用私有变量文件和凭据管理工具。

```shell
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
terraform output
terraform plan -var-file=terraform.tfvars
```

创建模式需在注册商配置输出的 NameServer 并完成域名所有权验证。既有模式的 `name_servers`、`zone_status` 为 null，需在外部检查委派和所有权。检查各类型 DNS 答案、MX 优先级 10、TXT 内容和线路路由，并确认禁用记录不生效。二次 Plan 必须无变更。

使用可选加权场景前，先在 Terraform 外部对既有区域准确的 `weighted`/`A`/`default` 记录集启用负载均衡，由独立所有者保留该设置。再设置 `enable_weighted_routing_example=true` 并传入 `existing_zone_id`。已有主备记录需使用 `zid|record_id` import 到模块的逻辑地址。模块传递 80/20 权重，不能启用或验证负载均衡开关；权重表示配置意图，不保证请求百分比。

已核对 Provider Schema 不包含健康检查路由或自动故障转移对应字段和资源。指向服务的 CNAME 是普通 CNAME，不是 Route53 别名或健康感知路由。这些场景暂缓实现。

```shell
terraform destroy -var-file=terraform.tfvars
```

创建模式删除拥有的记录和区域；既有模式仅删除拥有的记录。清理后查询 API 确认移除，并考虑 DNS TTL。外部负载均衡设置和外部记录仍由调用方拥有。2026-11-05，Terraform 1.5.7 与线上 Provider 0.0.73 已通过真实 Plan/Apply、全部九条记录的 API 回读、正常刷新后二次 Plan 无变更及标准 Destroy，十个资源全部确认删除。两个分配的权威服务器返回期望记录；注册商委派未改变，公网解析未通过。移动客户端线路行为、加权行为和故障转移仍未验证。
