# Inventory Excel Import Design

## Goal

让平台运营可以上传一张 `.xlsx` 货盘表，系统批量创建或更新供应商、仓库、药品主数据、供应商报价、可售区域和批号效期库存，并返回导入成功/失败统计。

## Scope

本阶段只做后台同步导入 API，不做异步队列、不做前端页面、不做 CSV、不做复杂模板下载。后续数据量大时再把同一个导入服务放进 Sidekiq。

## Endpoint

`POST /pharma/admin/api/v1/inventory_imports`

- 使用现有 `X-Pharma-Admin-Token`。
- multipart 参数：`file`。
- 文件必须是 `.xlsx`。

`GET /pharma/admin/api/v1/inventory_imports/:id`

- 查看导入记录、统计和错误明细。

## Import Record

新增 `Pharma::InventoryImport`：

- `original_filename`
- `status`: `pending`、`completed`、`completed_with_errors`、`failed`
- `total_rows`
- `success_rows`
- `failed_rows`
- `error_details`: JSON array，记录行号和错误信息

## Excel Headers

第一行必须是表头。支持这些中文列：

- `供应商编码`
- `供应商名称`
- `供应商联系人`
- `供应商电话`
- `供应商省`
- `供应商市`
- `仓库编码`
- `仓库名称`
- `仓库省`
- `仓库市`
- `仓库区`
- `仓库地址`
- `通用名`
- `商品名`
- `规格`
- `剂型`
- `生产厂家`
- `批准文号`
- `包装单位`
- `是否处方`
- `储存条件`
- `温控`
- `单价`
- `起订量`
- `限购量`
- `报价状态`
- `报价开始`
- `报价结束`
- `可售省`
- `可售市`
- `可售区`
- `配送天数`
- `批号`
- `效期`
- `库存`
- `锁定库存`

## Row Behavior

每一行独立事务：

- `供应商编码` 找到或创建供应商。新供应商默认 `pending`，避免未经审核的供应商直接参与可售匹配。
- `仓库编码` 找到或创建供应商仓库。
- `批准文号` 找到或创建药品主数据。
- 供应商、药品、仓库组合找到或创建报价。
- 报价和区域组合找到或创建可售区域。
- 供应商、仓库、药品、报价、批号找到或创建批号库存。

一行失败不会回滚其他行；错误写入 `error_details`。

## Testing

新增 service specs 覆盖成功导入、行级校验失败和无效文件。新增 request specs 覆盖 token、缺文件、成功上传和查看记录。

## Self-Review

- No placeholders: 本规格没有 TBD/TODO。
- Scope: 聚焦同步 `.xlsx` 导入，不包含 UI、异步队列、模板下载。
- Consistency: 导入落点复用现有 `Pharma` 模型和后台 API token 约定。
