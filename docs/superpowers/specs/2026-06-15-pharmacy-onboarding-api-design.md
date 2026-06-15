# Pharmacy Onboarding API Design

## Goal

补齐药店采购闭环入口：药店可以提交主体信息和经营资质，平台运营可以查看待审核药店、审核药店主体和审核药店资质。只有药店主体与至少一个资质都审核通过时，现有 `Pharma::Pharmacy#purchasing_enabled?` 才会允许其查看可购报价和后续下单。

## Scope

本阶段只做 JSON API，不做前端页面、不做短信验证、不做正式登录账号体系、不做文件上传存储。资质文件后续会单独接 ActiveStorage；当前先记录证照类型、编号、有效期和审核状态。

## Public Pharmacy API

- `POST /pharma/api/v1/pharmacies`
  - 创建药店主体，默认状态 `pending`。
  - 必填：`name`、`code`、`contact_name`、`contact_phone`、`province`、`city`、`address`。
- `POST /pharma/api/v1/pharmacies/:pharmacy_code/licenses`
  - 给药店提交一条资质记录，默认状态 `pending`。
  - 必填：`license_type`、`license_no`、`starts_on`、`expires_on`。

## Admin Pharmacy API

平台运营 API 继续使用 `X-Pharma-Admin-Token`。

- `GET /pharma/admin/api/v1/pharmacies?status=pending`
  - 查看药店列表，可按状态过滤。
- `GET /pharma/admin/api/v1/pharmacies/:id`
  - 查看药店详情和资质列表。
- `PATCH /pharma/admin/api/v1/pharmacies/:id/review`
  - 审核药店主体，允许 `approved`、`rejected`、`suspended`。
- `PATCH /pharma/admin/api/v1/pharmacy_licenses/:id/review`
  - 审核药店资质，允许 `approved`、`rejected`、`expired`。

## Error Handling

- `401 unauthorized`：平台 token 缺失或错误。
- `404 not_found`：药店或资质不存在。
- `422 validation_failed`：创建参数不合法或唯一性冲突。
- `422 invalid_status`：审核状态不在允许范围。

## Testing

新增 request specs 覆盖药店注册、重复 code、资质提交、平台列表、平台详情、药店主体审核、资质审核，以及审核通过后 `purchasing_enabled?` 生效。

## Self-Review

- No placeholders: 本规格没有 TBD/TODO。
- Scope: 聚焦药店入驻与审核 API，不包含 UI、账号、文件存储。
- Consistency: 复用现有 `Pharma::Pharmacy`、`Pharma::PharmacyLicense`、admin token API 约定。
