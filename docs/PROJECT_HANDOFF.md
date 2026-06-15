# 九州医药 B2B 订货系统项目交接文档

更新时间：2026-06-15  
当前分支：`feature/spree-pharma-foundation`  
当前提交：`c7fe20c feat: add pharmacy cart api`

## 1. 项目定位

本项目是基于 Spree Commerce 的医药 B2B 订货系统后端。目标场景是：药店在平台采购药品，平台基于全国货盘完成报价、库存匹配、订单分配、履约配送和后续票据/对账。

当前实现方式：

- Spree 负责通用电商底座：`Order`、`LineItem`、`Product`、`Variant`、Admin、Store API 等。
- 医药 B2B 领域能力放在 `Pharma` 命名空间下，避免把药品资质、批号效期、货盘、区域可售、履约规则硬塞进 Spree 原模型。
- 当前主要是 API 和后端领域能力，尚未做完整业务前端页面。

## 2. 技术栈

- Ruby / Rails：Rails 8.1，运行在 Docker dev 镜像中
- 电商底座：Spree 5.5 starter
- 数据库：PostgreSQL 18
- 队列：Redis + Sidekiq
- 搜索服务：Meilisearch
- 测试：RSpec
- 代码风格：RuboCop
- 本地开发：`docker-compose.dev.yml`

## 3. 当前运行状态

本地开发服务当前可通过 Docker Compose 启动：

- Web：http://localhost:3000
- Spree Admin：http://localhost:3000/admin
- Health：http://localhost:3000/up
- Sidekiq：http://localhost:3000/sidekiq
- Meilisearch：http://localhost:7700
- PostgreSQL host 端口：`localhost:5433`

开发环境默认后台账号：

- 邮箱：`spree@example.com`
- 密码：`spree123`

Admin API 开发环境默认 token：

- Header：`X-Pharma-Admin-Token: dev-admin-token`
- 生产环境应设置 `PHARMA_ADMIN_API_TOKEN`，不要使用默认值。

## 4. 安装与启动

### 4.1 首次准备

只要求本机安装 Docker Desktop、OrbStack 或兼容 Docker 运行时。不要在宿主机直接运行 Ruby/Rails。

```bash
cd /Users/wisecover/Desktop/jiuju_wms/.worktrees/spree-pharma-foundation
cp .env.example .env
```

生成并写入本地 `SECRET_KEY_BASE`：

```bash
secret="$(docker run --rm ruby:slim ruby -e 'require "securerandom"; print SecureRandom.hex(64)')"
grep -v '^SECRET_KEY_BASE=' .env.example > .env
printf 'SECRET_KEY_BASE=%s\nSPREE_PORT=3000\nSPREE_DB_PORT=5433\n' "$secret" >> .env
```

### 4.2 启动服务

```bash
docker compose -f docker-compose.dev.yml up -d --build
```

### 4.3 初始化数据库和种子数据

```bash
docker compose -f docker-compose.dev.yml exec web bin/rails db:prepare db:seed
```

`db:seed` 会：

- 加载 Spree 默认种子。
- 创建开发后台账号。
- 加载 `db/seeds/pharma_demo.rb` 医药演示数据。

医药演示数据包括：

- 供应商：`SUP-DEMO-001`
- 仓库：`WH-DEMO-001`
- 药品：阿莫西林胶囊，批准文号 `国药准字H00000001`
- 报价：`8.5`
- 区域：上海市
- 批号库存：`DEMO-BATCH-001`

### 4.4 常用命令

```bash
# 查看容器
docker compose -f docker-compose.dev.yml ps

# Rails console
docker compose -f docker-compose.dev.yml exec web bin/rails console

# 跑迁移
docker compose -f docker-compose.dev.yml exec web bin/rails db:migrate

# 查看路由
docker compose -f docker-compose.dev.yml exec web bin/rails routes

# 运行全量测试
docker compose -f docker-compose.dev.yml exec web bundle exec rspec

# 运行代码风格检查
docker compose -f docker-compose.dev.yml exec web bundle exec rubocop app/controllers/pharma app/models/pharma app/services/pharma spec/requests/pharma spec/services/pharma config/routes.rb

# 健康检查
curl -fsS http://localhost:3000/up

# 查看 web 日志
docker compose -f docker-compose.dev.yml logs -f web

# 停止服务
docker compose -f docker-compose.dev.yml down
```

## 5. 当前验证基线

最近一次验证结果：

```text
RSpec: 84 examples, 0 failures
RuboCop: 57 files inspected, no offenses detected
Health: /up 返回绿色页面
```

测试中会看到一些 Spree 自身的 deprecation warning，例如 `Product#available_on=`、`DefaultPrice`、`public_metadata`。当前不影响测试通过，但后续升级 Spree 6 前需要处理。

## 6. 已实现功能总览

### 6.1 基础领域模型

已实现 `Pharma` 命名空间下的核心模型：

- `Pharma::Pharmacy`：药店主体。
- `Pharma::PharmacyLicense`：药店资质。
- `Pharma::Supplier`：供应商/货盘方。
- `Pharma::SupplierLicense`：供应商资质。
- `Pharma::SupplierWarehouse`：供应商仓库。
- `Pharma::DrugMaster`：药品主数据。
- `Pharma::DrugVariantLink`：药品主数据与 Spree Variant 绑定。
- `Pharma::SupplierOffer`：供应商报价。
- `Pharma::SupplierOfferRegion`：报价可售区域。
- `Pharma::DrugBatchStock`：批号效期库存。
- `Pharma::OrderAllocation`：订单行到供应商/仓库/报价/批号的分配记录。
- `Pharma::SupplierFulfillment`：供应商履约单。
- `Pharma::SupplierVisibilityConfig`：前台供应商展示策略。
- `Pharma::InventoryImport`：货盘导入记录。

### 6.2 药店注册与资质

已实现：

- 药店注册 API。
- 药店资质提交 API。
- 后台药店列表/详情。
- 后台药店审核。
- 后台药店资质审核。
- 药店是否可采购由 `purchasing_enabled?` 判断，要求药店 approved 且有有效 approved 资质。

### 6.3 药品、供应商、报价、库存后台维护

已实现后台 API：

- 药品主数据 CRUD。
- 供应商 CRUD。
- 供应商资质创建/更新。
- 供应商仓库创建/更新。
- 供应商报价创建/更新。
- 报价可售区域创建/更新。
- 批号效期库存创建/更新。

### 6.4 货盘 Excel 导入

已实现同步 `.xlsx` 导入：

- 导入供应商、仓库、药品、报价、可售区域、批号库存。
- 每一行独立事务。
- 坏行进入 `error_details`，不影响其他行。
- 支持查看导入结果。

核心类：

- `Pharma::XlsxReader`
- `Pharma::InventoryImportProcessor`
- `Pharma::InventoryImport`

### 6.5 药店端药品搜索和报价匹配

已实现：

- 药店搜索药品。
- 查询某药品可售报价。
- 报价匹配会校验药店资质、供应商资质、区域、库存、效期、起订量/限购量。
- 排序逻辑在 `Pharma::OfferMatcher`。

### 6.6 供应商前台展示策略

已实现 `Pharma::SupplierVisibilityConfig` 和 `Pharma::SupplierVisibilityPolicy`：

- `hidden`：隐藏供应商，只显示平台标签。
- `partial`：显示区域仓/平台优选等有限信息。
- `visible`：展示供应商名称。

开发环境默认 `hidden`。

### 6.7 药店购物车和下单闭环

已实现药店端 API：

- 创建购物车。
- 查看购物车。
- 加入药品。
- 提交订单。

关键逻辑：

- 购物车使用 `Spree::Order`。
- 购物车行使用 `Spree::LineItem`。
- 加购时通过 `Pharma::OfferMatcher` 选择最优可售货盘。
- 加购时不锁库存。
- 提交订单时调用 `Pharma::OrderAllocator` 锁定库存，并生成 `OrderAllocation` 和 `SupplierFulfillment`。
- 当前临时用 `pharmacy_code` 识别药店，尚未接真实登录态。
- 加购时如果药品还没有 Spree Product/Variant，会自动创建最小 Spree Product + master Variant，并创建 `Pharma::DrugVariantLink`。

核心类：

- `Pharma::PharmacyCartService`
- `Pharma::OrderAllocator`

### 6.8 后台半自动订单分配

已实现后台分配 API：

- 运营人员可指定 Spree order、line item、supplier offer、batch stock 和数量。
- 系统校验报价可用、库存可用、效期、供应商资质。
- 成功后锁定库存，创建订单分配和供应商履约单。

### 6.9 履约状态流转

已实现供应商履约单后台 API：

- 列表。
- 详情。
- 状态流转。

状态规则：

- `pending -> picking`
- `pending/picking -> shipped`
- `shipped -> received`
- `pending/picking -> canceled`

同步逻辑：

- 发货时相关 allocation 从 `allocated` 变 `confirmed`。
- 签收时相关 allocation 变 `fulfilled`。
- 取消时相关 allocation 变 `canceled`，并释放已锁库存。

核心类：

- `Pharma::SupplierFulfillmentWorkflow`

## 7. API 总览

### 7.1 药店端 API

无需 admin token。当前用 `pharmacy_code` 识别药店。

```text
POST /pharma/api/v1/pharmacies
POST /pharma/api/v1/pharmacies/:pharmacy_code/licenses

GET  /pharma/api/v1/drugs
GET  /pharma/api/v1/drugs/:id/offers

POST /pharma/api/v1/carts
GET  /pharma/api/v1/carts/:number
POST /pharma/api/v1/carts/:number/items
POST /pharma/api/v1/carts/:number/checkout
```

### 7.2 后台运营 API

需要 Header：

```text
X-Pharma-Admin-Token: dev-admin-token
```

接口：

```text
GET   /pharma/admin/api/v1/pharmacies
GET   /pharma/admin/api/v1/pharmacies/:id
PATCH /pharma/admin/api/v1/pharmacies/:id/review
PATCH /pharma/admin/api/v1/pharmacy_licenses/:id/review

GET   /pharma/admin/api/v1/drug_masters
POST  /pharma/admin/api/v1/drug_masters
GET   /pharma/admin/api/v1/drug_masters/:id
PATCH /pharma/admin/api/v1/drug_masters/:id

GET   /pharma/admin/api/v1/suppliers
POST  /pharma/admin/api/v1/suppliers
GET   /pharma/admin/api/v1/suppliers/:id
PATCH /pharma/admin/api/v1/suppliers/:id
POST  /pharma/admin/api/v1/suppliers/:supplier_id/licenses
PATCH /pharma/admin/api/v1/supplier_licenses/:id
POST  /pharma/admin/api/v1/suppliers/:supplier_id/warehouses
PATCH /pharma/admin/api/v1/supplier_warehouses/:id

GET   /pharma/admin/api/v1/supplier_offers
POST  /pharma/admin/api/v1/supplier_offers
GET   /pharma/admin/api/v1/supplier_offers/:id
PATCH /pharma/admin/api/v1/supplier_offers/:id
POST  /pharma/admin/api/v1/supplier_offers/:supplier_offer_id/regions
PATCH /pharma/admin/api/v1/supplier_offer_regions/:id

POST  /pharma/admin/api/v1/drug_batch_stocks
PATCH /pharma/admin/api/v1/drug_batch_stocks/:id

POST  /pharma/admin/api/v1/inventory_imports
GET   /pharma/admin/api/v1/inventory_imports/:id

GET   /pharma/admin/api/v1/supplier_visibility_config
PATCH /pharma/admin/api/v1/supplier_visibility_config

POST  /pharma/admin/api/v1/order_allocations

GET   /pharma/admin/api/v1/supplier_fulfillments
GET   /pharma/admin/api/v1/supplier_fulfillments/:id
PATCH /pharma/admin/api/v1/supplier_fulfillments/:id/transition
```

## 8. 关键业务流程

### 8.1 货盘维护流程

1. 后台创建供应商、资质、仓库。
2. 后台创建药品主数据。
3. 后台创建报价、可售区域、批号库存。
4. 或者通过 Excel 一次导入上述数据。

### 8.2 药店准入流程

1. 药店提交注册信息。
2. 药店提交资质。
3. 后台审核药店主体。
4. 后台审核药店资质。
5. 药店变为可采购。

### 8.3 药店下单流程

1. 药店搜索药品。
2. 药店查询可售报价。
3. 药店创建购物车。
4. 药店加入药品。
5. 系统匹配最优货盘并保存快照。
6. 药店提交购物车。
7. 系统锁定库存。
8. 系统生成订单分配和供应商履约单。

### 8.4 履约流程

1. 后台查看供应商履约单。
2. 标记开始拣货。
3. 标记发货并记录物流公司/单号。
4. 标记签收。
5. 或在未发货前取消履约，释放锁定库存。

## 9. 重要代码位置

### 9.1 领域模型

```text
app/models/pharma/*.rb
```

### 9.2 核心服务

```text
app/services/pharma/offer_matcher.rb
app/services/pharma/order_allocator.rb
app/services/pharma/pharmacy_cart_service.rb
app/services/pharma/supplier_fulfillment_workflow.rb
app/services/pharma/inventory_import_processor.rb
app/services/pharma/xlsx_reader.rb
app/services/pharma/supplier_visibility_policy.rb
```

### 9.3 药店端 API

```text
app/controllers/pharma/api/v1/*.rb
```

### 9.4 后台运营 API

```text
app/controllers/pharma/admin/api/v1/*.rb
```

### 9.5 设计和计划文档

```text
docs/superpowers/specs/*.md
docs/superpowers/plans/*.md
```

建议新同事先读：

1. `docs/superpowers/specs/2026-06-14-spree-pharma-b2b-design.md`
2. `docs/superpowers/specs/2026-06-15-pharmacy-cart-checkout-design.md`
3. `docs/superpowers/specs/2026-06-15-inventory-excel-import-design.md`
4. `docs/superpowers/specs/2026-06-15-supplier-fulfillment-workflow-design.md`

## 10. 测试结构

主要测试目录：

```text
spec/models/pharma
spec/services/pharma
spec/requests/pharma
```

重点测试文件：

- `spec/services/pharma/offer_matcher_spec.rb`
- `spec/services/pharma/order_allocator_spec.rb`
- `spec/services/pharma/pharmacy_cart_service_spec.rb`
- `spec/services/pharma/inventory_import_processor_spec.rb`
- `spec/services/pharma/supplier_fulfillment_workflow_spec.rb`
- `spec/requests/pharma/api/v1/carts_spec.rb`
- `spec/requests/pharma/admin/api/v1/master_data_spec.rb`
- `spec/requests/pharma/admin/api/v1/inventory_imports_spec.rb`
- `spec/requests/pharma/admin/api/v1/supplier_fulfillments_spec.rb`

运行：

```bash
docker compose -f docker-compose.dev.yml exec web bundle exec rspec
```

只跑医药相关：

```bash
docker compose -f docker-compose.dev.yml exec web bundle exec rspec spec/models/pharma spec/services/pharma spec/requests/pharma
```

## 11. 协同开发建议

### 11.1 分支策略

当前开发分支是：

```text
feature/spree-pharma-foundation
```

多人协同时建议：

- 每个功能从当前基础分支切独立 feature 分支。
- 每个功能至少包含：设计文档或任务说明、测试、实现、验证记录。
- 提交保持小而清晰，例如：
  - `docs: plan invoice records`
  - `feat: add invoice record model`
  - `feat: add invoice admin api`
  - `fix: validate settlement period`

### 11.2 开发顺序

建议遵循：

1. 先写/更新 `docs/superpowers/specs` 中的设计。
2. 再写 `docs/superpowers/plans` 中的实施计划。
3. 先写失败测试。
4. 再实现。
5. 跑 RSpec、RuboCop、健康检查。
6. 提交。

### 11.3 不要随意改的边界

- 不要把医药业务规则直接塞进 Spree 原模型，优先放到 `Pharma` 命名空间。
- 不要跳过药店/供应商资质校验。
- 不要在加购阶段锁库存，当前设计是在 checkout 阶段锁库存。
- 不要直接改库存数量绕过 `OrderAllocator` 或履约取消释放逻辑。
- 不要把生产 token、真实账号密码、证照文件提交进 Git。

## 12. 当前已知限制

这些不是 bug，是当前阶段尚未实现或临时实现：

- 药店端还没有真实登录态，当前用 `pharmacy_code` 识别。
- 后台运营 API 仍是 token 鉴权，没有细粒度 RBAC。
- 还没有药店端前端页面。
- 还没有后台运营前端页面。
- 还没有支付、账期、授信。
- 还没有发票、对账、结算模块。
- 还没有随货资料、质检报告、冷链记录、追溯码。
- Excel 导入是同步处理，不适合超大文件。
- Excel 导入还没有模板下载和导入历史列表筛选。
- 药品到 Spree Product/Variant 目前是最小绑定，后续需要做正式商品发布、图片、分类、价格体系。
- Spree 相关 deprecation warning 后续需要处理，尤其是升级到 Spree 6 前。

## 13. 下一步建议

### P0：协同开发前必须优先补

1. **账号和权限体系**
   - 药店用户登录。
   - 药店与用户绑定。
   - 后台角色权限。
   - API 操作审计。

2. **基础页面**
   - 药店端：搜索、商品详情、购物车、订单列表。
   - 后台端：药店审核、货盘管理、导入历史、订单分配、履约管理。

3. **订单详情和订单列表 API**
   - 药店查看自己的订单。
   - 后台查看订单、分配、履约状态。
   - 当前已有下单和履约底层，但订单查询 API 还不完整。

### P1：采购闭环增强

1. **发票记录**
   - 发票抬头、税号、开票状态、文件。

2. **对账/结算**
   - 药店对账。
   - 供应商结算。
   - 平台毛利/差价统计。

3. **售后/取消/退货**
   - 订单取消。
   - 退货退款。
   - 库存回滚。

4. **货盘导入增强**
   - 模板下载。
   - 异步导入。
   - 导入历史列表。
   - 错误文件导出。

### P2：合规和供应商能力

1. **随货资料**
   - 随货同行单。
   - 质检报告。
   - 冷链记录。

2. **追溯码**
   - 批号与追溯码绑定。
   - 订单发货追溯码上传。

3. **供应商自助后台**
   - 供应商维护报价和库存。
   - 供应商处理发货。
   - 供应商上传票据和资料。

4. **实时库存同步**
   - 供应商 API 对接。
   - 定时同步。
   - 库存差异告警。

## 14. 快速联调示例

### 14.1 查看药品

```bash
curl "http://localhost:3000/pharma/api/v1/drugs?query=阿莫西林"
```

### 14.2 查询可售报价

```bash
curl "http://localhost:3000/pharma/api/v1/drugs/1/offers?pharmacy_code=PH-DEMO-001&quantity=10&province=上海市&city=上海市"
```

注意：演示种子目前提供货盘数据，不默认创建 approved 药店。联调前需要通过 API 创建药店、提交资质，再用后台 API 审核通过。

### 14.3 创建购物车

```bash
curl -X POST "http://localhost:3000/pharma/api/v1/carts" \
  -d "pharmacy_code=PH-DEMO-001" \
  -d "email=buyer@example.com"
```

### 14.4 后台 API 调用格式

```bash
curl -H "X-Pharma-Admin-Token: dev-admin-token" \
  "http://localhost:3000/pharma/admin/api/v1/supplier_visibility_config"
```

## 15. 交接检查清单

新同事接手时建议按这个顺序确认：

1. 能拉起 Docker Compose。
2. 能访问 http://localhost:3000/up。
3. 能登录 Spree Admin。
4. 能运行 `bundle exec rspec` 并通过。
5. 能运行 RuboCop 并通过。
6. 能读懂 `Pharma` 模型边界。
7. 能用 API 创建药店、审核药店、搜索药品、创建购物车并 checkout。
8. 能在后台看到履约单并执行发货/签收流转。
9. 再开始领取新模块。
