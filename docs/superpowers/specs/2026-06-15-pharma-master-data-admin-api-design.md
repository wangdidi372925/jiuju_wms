# Pharma Master Data Admin API Design

## Goal

让平台运营可以通过 JSON API 维护第一版采购闭环所需的基础数据：药品主数据、供应商、供应商资质、供应商仓库、报价、可售区域和批号效期库存。

## Scope

本阶段只做后台 JSON API，不做前端页面，不做 Excel 导入，不做删除能力。删除容易影响订单、库存和追溯，第一版先用 `status` 字段停用数据。

## Admin API

所有接口使用现有 `X-Pharma-Admin-Token`。

- `GET /pharma/admin/api/v1/drug_masters`
- `GET /pharma/admin/api/v1/drug_masters/:id`
- `POST /pharma/admin/api/v1/drug_masters`
- `PATCH /pharma/admin/api/v1/drug_masters/:id`
- `GET /pharma/admin/api/v1/suppliers`
- `GET /pharma/admin/api/v1/suppliers/:id`
- `POST /pharma/admin/api/v1/suppliers`
- `PATCH /pharma/admin/api/v1/suppliers/:id`
- `POST /pharma/admin/api/v1/suppliers/:supplier_id/licenses`
- `PATCH /pharma/admin/api/v1/supplier_licenses/:id`
- `POST /pharma/admin/api/v1/suppliers/:supplier_id/warehouses`
- `PATCH /pharma/admin/api/v1/supplier_warehouses/:id`
- `POST /pharma/admin/api/v1/supplier_offers`
- `PATCH /pharma/admin/api/v1/supplier_offers/:id`
- `POST /pharma/admin/api/v1/supplier_offers/:supplier_offer_id/regions`
- `PATCH /pharma/admin/api/v1/supplier_offer_regions/:id`
- `POST /pharma/admin/api/v1/drug_batch_stocks`
- `PATCH /pharma/admin/api/v1/drug_batch_stocks/:id`

## Behavior

- 列表接口按 `created_at desc` 返回最多 50 条。
- 创建和更新复用现有模型校验。
- 供应商详情包含资质和仓库。
- 报价详情包含区域和批号库存。
- 所有 validation 失败返回 `422 validation_failed`。
- 找不到记录返回 `404 not_found`。
- token 缺失返回 `401 unauthorized`。

## Testing

新增 request specs 覆盖每类资源至少一条创建、更新和关键嵌套返回，确保后续 Excel 导入可复用这些模型路径。

## Self-Review

- No placeholders: 本规格没有 TBD/TODO。
- Scope: 不包含 UI、删除、Excel 导入。
- Consistency: 复用现有 `Pharma` 模型和 admin token 约定。
