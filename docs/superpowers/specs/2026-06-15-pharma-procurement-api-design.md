# Pharma Procurement API Design

## Goal

把当前已经完成的医药 B2B 后端模型和匹配服务暴露成可调用的最小 API，让药店端可以搜索药品和查看可购报价，让平台运营可以配置供应商展示策略，并可以把 Spree 订单行分配到供应商货盘、批号库存和履约单。

## Scope

本阶段只做 JSON API 和一个订单分配服务，不做前端页面、不做供应商自助后台、不做支付、发票、结算和追溯自动化。

## API Boundaries

- 药店端 API 使用 `/pharma/api/v1/*`。
- 平台运营 API 使用 `/pharma/admin/api/v1/*`。
- 平台运营 API 暂用 `X-Pharma-Admin-Token` 头校验，token 来自 `PHARMA_ADMIN_API_TOKEN`，开发环境默认 `dev-admin-token`。
- 药店端 API 暂用 `pharmacy_code` 参数识别药店。后续接入登录后再替换为当前登录药店。

## Endpoints

### Drug Search

`GET /pharma/api/v1/drugs?query=阿莫西林`

返回 active 药品主数据，按更新时间倒序，最多 20 条。搜索字段包括通用名、商品名、规格、厂家、批准文号。

### Offer Matching

`GET /pharma/api/v1/drugs/:drug_id/offers?pharmacy_code=PH001&quantity=10&province=上海市&city=上海市`

使用 `Pharma::OfferMatcher` 返回当前药店可购报价。返回值遵守 `Pharma::SupplierVisibilityConfig.current`，默认隐藏供应商名称，但后台仍保留真实供应商信息。

### Supplier Visibility Config

`GET /pharma/admin/api/v1/supplier_visibility_config`

`PATCH /pharma/admin/api/v1/supplier_visibility_config`

平台运营读取或修改供应商展示策略。只允许 `hidden`、`partial`、`visible`。

### Order Allocation

`POST /pharma/admin/api/v1/order_allocations`

运营人员提交 `spree_order_id`、`spree_line_item_id`、`supplier_offer_id`、`drug_batch_stock_id` 和 `quantity`。系统在事务里：

- 校验订单行属于订单。
- 校验报价和库存仍可用。
- 增加批号库存锁定量。
- 创建 `Pharma::OrderAllocation`。
- 为同一订单、供应商和仓库复用或创建 `Pharma::SupplierFulfillment`。

## Error Handling

所有 API 返回 JSON。常见错误：

- `401 unauthorized`：平台运营 token 错误。
- `404 not_found`：药店、药品、订单、订单行、报价或库存不存在。
- `422 unprocessable_entity`：参数非法、药店无资质、库存不足、显示策略非法。

## Testing

新增 request specs 覆盖药品搜索、报价匹配、供应商显示策略配置、订单分配 API。新增 service spec 覆盖订单分配事务、锁库存和履约单创建。

## Self-Review

- No placeholders: 本规格没有 TBD/TODO。
- Scope: 聚焦下一阶段最小 API，不包含 UI、支付、发票、结算、追溯自动化。
- Consistency: 命名沿用 `Pharma` namespace、`SupplierVisibilityConfig`、`OfferMatcher`、`OrderAllocation`、`SupplierFulfillment`。
