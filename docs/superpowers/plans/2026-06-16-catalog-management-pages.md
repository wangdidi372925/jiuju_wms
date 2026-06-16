# 货盘管理页面完整版 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把运营端 `/pharma/ops` 的货盘页面从只读列表升级为可维护后台，运营人员可以在页面上维护货盘方、资质、仓库、药品主数据、报价、可售区域、批号库存，并上传 Excel 货盘。

**Architecture:** 复用现有 `Pharma` 模型、校验和导入服务，在 `Pharma::Ops` 页面层新增表单控制器。页面直接写领域模型，不绕一层 HTTP 调用现有 API，避免本机内部请求和 token 转发复杂度；API 仍保留给未来前后端分离或外部系统使用。

**Tech Stack:** Rails 8.1, Spree 5.5, ERB, RSpec request specs, PostgreSQL.

---

## Scope

本轮完成：

- 货盘方列表、新增、编辑、详情。
- 货盘方资质新增、编辑。
- 货盘方仓库新增、编辑。
- 药品主数据列表、新增、编辑。
- 报价列表、新增、编辑、详情。
- 报价可售区域新增、编辑。
- 批号库存新增、编辑。
- Excel 导入上传、导入历史列表、导入详情。

本轮不做：

- 删除能力。
- 供应商自助后台。
- 异步导入。
- 错误文件下载。
- 复杂库存预警规则。

## File Structure

- Modify `config/routes.rb`: 增加运营端货盘维护页面路由。
- Modify `app/controllers/pharma/ops/catalog_controller.rb`: 保留货盘总览，并补充必要筛选数据。
- Create `app/controllers/pharma/ops/suppliers_controller.rb`: 供应商列表、新增、编辑、详情。
- Create `app/controllers/pharma/ops/supplier_licenses_controller.rb`: 供应商资质新增、编辑。
- Create `app/controllers/pharma/ops/supplier_warehouses_controller.rb`: 供应商仓库新增、编辑。
- Create `app/controllers/pharma/ops/drug_masters_controller.rb`: 药品主数据列表、新增、编辑。
- Create `app/controllers/pharma/ops/supplier_offers_controller.rb`: 报价列表、新增、编辑、详情。
- Create `app/controllers/pharma/ops/supplier_offer_regions_controller.rb`: 可售区域新增、编辑。
- Create `app/controllers/pharma/ops/drug_batch_stocks_controller.rb`: 批号库存新增、编辑。
- Create `app/controllers/pharma/ops/inventory_imports_controller.rb`: Excel 导入上传、历史、详情。
- Create/modify `app/views/pharma/ops/...`: 对应页面和表单 partial。
- Modify `app/views/layouts/pharma_ops.html.erb`: 增加货盘维护导航入口。
- Modify `app/assets/stylesheets/application.css`: 补表单、select、文本域、操作区样式。
- Create `spec/requests/pharma/ops/catalog_management_spec.rb`: 覆盖运营页面核心维护流程。
- Modify `docs/PROJECT_HANDOFF.md`: 更新货盘管理页面能力和联调路径。

## Tasks

### Task 1: Request Specs

- [x] 写 `spec/requests/pharma/ops/catalog_management_spec.rb`。
- [x] 覆盖供应商新增/编辑、资质新增、仓库新增。
- [x] 覆盖药品新增/编辑。
- [x] 覆盖报价新增、区域新增、批号库存新增。
- [x] 覆盖 Excel 导入上传和导入详情。
- [x] 运行该 spec，确认因页面未实现失败。

### Task 2: Routes And Shared Form Behavior

- [x] 增加 `/pharma/ops/suppliers`、`/drug_masters`、`/supplier_offers`、`/inventory_imports` 等路由。
- [x] 在控制器内统一使用 `redirect_back` 或详情页展示校验错误。
- [x] 页面表单用现有模型字段，状态枚举从模型常量读取。

### Task 3: Supplier Maintenance

- [x] 实现供应商列表、新增、编辑、详情。
- [x] 实现供应商资质新增、编辑。
- [x] 实现供应商仓库新增、编辑。
- [x] 在供应商详情页展示资质和仓库，并提供快捷新增入口。

### Task 4: Drug And Offer Maintenance

- [x] 实现药品主数据列表、新增、编辑。
- [x] 实现报价列表、新增、编辑、详情。
- [x] 在报价表单中选择供应商、仓库、药品。
- [x] 在报价详情页维护可售区域和批号库存。

### Task 5: Excel Import Pages

- [x] 实现导入历史列表。
- [x] 实现 `.xlsx` 上传表单。
- [x] 实现导入详情页，展示成功/失败行数和错误明细。

### Task 6: Docs And Verification

- [x] 更新交接文档。
- [x] 跑货盘页面 spec。
- [x] 跑 ops/portal request specs。
- [x] 跑全量 RSpec。
- [x] 跑 RuboCop。
- [x] 跑 seed 和 `/up`。
