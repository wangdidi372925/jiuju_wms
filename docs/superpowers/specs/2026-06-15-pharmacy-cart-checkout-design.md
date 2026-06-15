# Pharmacy Cart Checkout Design

## Goal

让已审核药店可以通过 API 创建购物车、加入药品、查看购物车并提交订单。提交时系统按已选货盘锁定批号库存，生成订单分配和供应商履约单，跑通第一版“药店下单 -> 平台分配 -> 后台履约”的采购闭环。

## Scope

本阶段只做药店端同步 API 和服务层，不做前端页面、不做支付、不做发票、不做优惠、不做真实登录。接口临时使用 `pharmacy_code` 识别药店，后续账号体系完成后再替换为登录态。

本阶段不自动创建 Spree 商品和 Variant。购物车使用 `Spree::Order`，行项目使用 `Spree::LineItem`，医药业务信息记录在 line item `private_metadata` 中。后续单独实现药品主数据到 Spree 商品/Variant 的深度打通。

## Endpoints

`POST /pharma/api/v1/carts`

- 参数：`pharmacy_code`、`email` 可选。
- 药店必须已审核并持有效资质。
- 创建 `Spree::Order`，状态保持 `cart`，`private_metadata` 写入药店信息。

`GET /pharma/api/v1/carts/:number`

- 参数：`pharmacy_code`。
- 只允许查看属于该药店的购物车。

`POST /pharma/api/v1/carts/:number/items`

- 参数：`pharmacy_code`、`drug_master_id`、`quantity`、`province`、`city` 可选。
- 系统复用 `Pharma::OfferMatcher` 找到最优可售报价。
- 选择该报价下可用批号库存，创建 `Spree::LineItem`，记录药品、报价、库存、供应商、仓库快照。
- 此阶段不锁库存，库存锁定发生在提交订单时。

`POST /pharma/api/v1/carts/:number/checkout`

- 参数：`pharmacy_code`。
- 校验购物车属于该药店、未提交、至少有一行。
- 对每行调用 `Pharma::OrderAllocator`，锁定库存并生成 allocation/fulfillment。
- 更新 `Spree::Order` 为已完成，写入 `completed_at`、`item_total`、`total`、`item_count`。

## Error Handling

返回现有 JSON 错误格式：

- `pharmacy_not_allowed`：药店未审核或资质无效。
- `cart_not_open`：购物车已经提交。
- `empty_cart`：空购物车不能提交。
- `invalid_quantity`：数量小于等于 0。
- `offer_unavailable`：没有可售报价或库存。
- `cart_owner_mismatch`：购物车不属于当前药店。
- 下单分配失败时透传 `Pharma::OrderAllocator::AllocationError` 的 code。

## Data Flow

1. 药店创建购物车。
2. 药店加入药品，系统匹配最优报价并保存快照。
3. 药店提交购物车。
4. 每个购物车行通过 `OrderAllocator` 生成分配并锁库存。
5. 相同订单、供应商、仓库复用同一供应商履约单。

## Testing

新增 service specs 覆盖创建购物车、加入商品、空车提交失败、未审核药店失败、提交成功并锁库存。新增 request specs 覆盖创建、查看、加入商品、提交和错误返回。

## Self-Review

- No placeholders: 本规格没有 TBD/TODO。
- Scope: 聚焦药店端 API 下单闭环，不包含页面、支付、发票、账号登录。
- Consistency: 复用现有 `Pharma::OfferMatcher`、`Pharma::OrderAllocator`、`Spree::Order` 和 `Spree::LineItem`。
