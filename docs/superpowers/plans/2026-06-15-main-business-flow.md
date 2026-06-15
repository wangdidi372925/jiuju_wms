# 主业务闭环 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让当前医药 B2B 系统可以从浏览器完成一次核心流程：药店登录、查药、加购、下单、平台查看订单、发货、药店确认收货，并把库存从锁定转为真实出库。

**Architecture:** 继续复用现有 `Pharma` 后端领域模型和 API 服务，不重写 Spree Admin。新增轻量 Rails HTML 页面：`/pharma/portal` 给药店买家使用，`/pharma/ops` 给平台运营使用。订单异常和收货逻辑沉到服务层，页面和 API 后续都能复用。

**Tech Stack:** Rails 8.1, Spree 5.5, ERB, Turbo, RSpec request/service specs, PostgreSQL.

---

## File Structure

- Create `app/services/pharma/order_status_sync.rb`: 根据分配和履约状态同步 Spree order 的业务状态。
- Create `app/services/pharma/order_cancellation_service.rb`: 取消未发货订单，释放锁定库存。
- Modify `app/services/pharma/supplier_fulfillment_workflow.rb`: 收货时释放锁定库存并扣减现货库存。
- Create `app/controllers/pharma/portal/*`: 药店端浏览器页面控制器。
- Create `app/controllers/pharma/ops/*`: 平台运营端浏览器页面控制器。
- Create `app/views/layouts/pharma_portal.html.erb` and `app/views/layouts/pharma_ops.html.erb`: 两套轻量业务布局。
- Create `app/views/pharma/portal/**/*`: 登录、药品、购物车、订单页面。
- Create `app/views/pharma/ops/**/*`: 登录、看板、药店审核、货盘、订单、履约页面。
- Modify `config/routes.rb`: 增加 `/pharma/portal` 和 `/pharma/ops` 页面路由。
- Create `spec/services/pharma/order_cancellation_service_spec.rb`: 覆盖取消订单和释放库存。
- Modify `spec/services/pharma/supplier_fulfillment_workflow_spec.rb`: 覆盖收货扣库存。
- Create `spec/requests/pharma/portal/flow_spec.rb`: 覆盖药店页面下单和确认收货。
- Create `spec/requests/pharma/ops/flow_spec.rb`: 覆盖运营页面审核和发货。
- Modify `docs/PROJECT_HANDOFF.md`: 更新当前主流程入口和验证方式。

---

### Task 1: 订单状态和库存出库

- [ ] Write failing service specs for cancel and receive.
- [ ] Add `Pharma::OrderStatusSync`.
- [ ] Add `Pharma::OrderCancellationService`.
- [ ] Update `Pharma::SupplierFulfillmentWorkflow#receive!` to reduce `quantity_locked` and `quantity_on_hand`.
- [ ] Run service specs and keep existing fulfillment specs green.

Expected behavior:

- Pending/picking fulfillments can be canceled and locked stock is released.
- Shipped fulfillments can be received.
- Receive changes related allocations to `fulfilled`.
- Receive decrements locked stock and on-hand stock exactly once.
- Order status becomes `canceled`, `shipped`, or `completed` according to fulfillments.

### Task 2: 药店端采购页面

- [ ] Add portal session controller using `Pharma::PharmacySessionService`.
- [ ] Add portal base controller with current pharmacy user and pharmacy helpers.
- [ ] Add drug catalog page with search, province/city/quantity offer lookup, and add-to-cart form.
- [ ] Add cart page with add item, checkout, and current cart state.
- [ ] Add orders list/detail pages with cancel and confirm-receipt actions.
- [ ] Add request spec that logs in, adds seeded stock to cart, checks out, and sees the order detail.

Expected behavior:

- Buyer can log in with `buyer@example.com / buyer123 / PH-DEMO-001`.
- Buyer can search `阿莫西林`.
- Buyer can add a valid offer to cart.
- Buyer can submit the cart and see a placed order.
- Buyer can confirm receipt after operations ships the fulfillment.

### Task 3: 平台运营页面

- [ ] Add ops session controller using `dev-admin-token` or a database admin token.
- [ ] Add ops base controller with admin token session validation.
- [ ] Add dashboard with counts for pending pharmacies, orders, fulfillments, and low stock.
- [ ] Add pharmacy review pages with approve/reject actions for pharmacy and license.
- [ ] Add catalog page showing drugs, offers, stock, and availability.
- [ ] Add orders and fulfillments pages with ship/cancel/receive transition forms.
- [ ] Add request spec that logs in as ops and ships a fulfillment.

Expected behavior:

- Operator can log in with `dev-admin-token`.
- Operator can review pharmacy/license.
- Operator can inspect orders and fulfillments.
- Operator can ship a fulfillment with logistics company/tracking number.

### Task 4: 文档和验证

- [ ] Update handoff docs with browser routes and the end-to-end manual smoke path.
- [ ] Run focused specs.
- [ ] Run full RSpec.
- [ ] Run RuboCop.
- [ ] Run `db:seed`.
- [ ] Open the app in the browser and manually run the main flow.

Expected verification:

- RSpec passes.
- RuboCop has no offenses for touched files.
- `/up` returns 200.
- Browser flow reaches an order detail with received/completed state.
