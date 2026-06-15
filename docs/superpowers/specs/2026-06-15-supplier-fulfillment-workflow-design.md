# Supplier Fulfillment Workflow Design

## Goal

让平台运营在后台推进供应商履约单状态：确认拣货、发货、签收或取消，并同步订单分配状态，跑通“货盘分配 -> 履约发货 -> 药店签收”的第一版闭环。

## Scope

本阶段只做后台同步 API 和服务层状态机，不做前端页面、不做供应商自助后台、不做真实物流接口、不做短信通知。

## Endpoints

`GET /pharma/admin/api/v1/supplier_fulfillments`

- 使用现有 `X-Pharma-Admin-Token`。
- 返回最近 50 条履约单。
- 可选 `status` 过滤。

`GET /pharma/admin/api/v1/supplier_fulfillments/:id`

- 查看履约单详情和同订单、同供应商、同仓库下的订单分配。

`PATCH /pharma/admin/api/v1/supplier_fulfillments/:id/transition`

- 参数：
  - `event`: `start_picking`、`ship`、`receive`、`cancel`
  - `delivery_company`: 发货时可选
  - `delivery_tracking_no`: 发货时可选

## State Rules

履约单状态：

- `pending -> picking`：运营确认开始拣货。
- `pending/picking -> shipped`：发货，写入 `shipped_at`。
- `shipped -> received`：药店签收，写入 `received_at`，并把关联分配标记为 `fulfilled`。
- `pending/picking -> canceled`：取消履约，并把关联分配标记为 `canceled`。

非法流转返回业务错误，不修改数据。

## Allocation Sync

当前 `SupplierFulfillment` 没有直接关联 allocation 表。第一版用 `spree_order_id + supplier_id + supplier_warehouse_id` 查找关联 `Pharma::OrderAllocation`：

- `ship` 时把 `allocated` 的分配推进为 `confirmed`。
- `receive` 时把关联分配推进为 `fulfilled`。
- `cancel` 时把关联分配推进为 `canceled`。

## Testing

新增 service specs 覆盖合法流转、非法流转、发货字段、签收同步分配、取消同步分配。新增 request specs 覆盖鉴权、列表、详情、流转成功、业务错误。

## Self-Review

- No placeholders: 本规格没有 TBD/TODO。
- Scope: 聚焦后台履约状态机和 API。
- Consistency: 复用现有 `SupplierFulfillment`、`OrderAllocation`、admin token 和 JSON API 风格。
