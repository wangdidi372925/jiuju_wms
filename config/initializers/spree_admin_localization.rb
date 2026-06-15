# frozen_string_literal: true

Rails.application.config.after_initialize do
  next unless defined?(Spree.admin)

  chinese_runtime_partial = 'spree/admin/shared/chinese_admin_runtime'
  unless Spree.admin.partials.head.include?(chinese_runtime_partial)
    Spree.admin.partials.head << chinese_runtime_partial
  end

  sidebar = Spree.admin.navigation.sidebar
  sidebar.update(:settings_section, section_label: '设置') if sidebar&.exists?(:settings_section)

  table_placeholders = {
    allowed_origins: '搜索允许来源',
    api_keys: '搜索 API 密钥',
    channels: '搜索渠道',
    checkouts: '搜索草稿订单',
    coupon_codes: '搜索优惠码',
    customer_groups: '搜索客户分组',
    customer_group_users: '搜索客户',
    customer_returns: '搜索客户退货',
    gift_cards: '搜索礼品卡',
    markets: '搜索市场',
    metafield_definitions: '搜索元字段定义',
    newsletter_subscribers: '搜索订阅用户',
    orders: '搜索订单',
    option_types: '搜索规格选项',
    policies: '搜索政策',
    price_lists: '搜索价格表',
    price_list_products: '搜索产品',
    products: '搜索产品',
    promotions: '搜索促销',
    refund_reasons: '搜索退款原因',
    reimbursement_types: '搜索退款类型',
    return_authorizations: '搜索退货审批',
    return_authorization_reasons: '搜索退货审批原因',
    shipping_categories: '搜索配送类型',
    shipping_methods: '搜索配送方式',
    stock_items: '搜索库存项',
    stock_locations: '搜索库存区域',
    stock_movements: '搜索库存变动',
    stock_transfers: '搜索库存转移',
    tax_categories: '搜索缴税分类',
    tax_rates: '搜索税率',
    taxonomies: '搜索分类层级',
    users: '搜索用户',
    webhook_endpoints: '搜索回调端点',
    zones: '搜索区域'
  }
  table_placeholders.each do |table, placeholder|
    next unless Spree.admin.tables.registered?(table)

    Spree.admin.tables.get(table).search_placeholder = placeholder
  end

  status_label = ->(record) { record.active? ? '启用' : '停用' }
  {
    channels: :active,
    refund_reasons: :active,
    reimbursement_types: :active,
    return_authorization_reasons: :active
  }.each do |table, column|
    next unless Spree.admin.tables.registered?(table)

    Spree.admin.tables.get(table).update(column, method: status_label)
  end

  if Spree.admin.tables.registered?(:api_keys)
    Spree.admin.tables.get(:api_keys).update(
      :key_type,
      method: ->(api_key) { I18n.t("spree.admin.api_keys.key_types.#{api_key.key_type}", default: api_key.key_type.to_s) }
    )
  end

  if Spree.admin.tables.registered?(:shipping_methods)
    display_on_labels = {
      'both' => '前后台',
      'frontend' => '仅前台',
      'backend' => '仅后台',
      'front_end' => '仅前台',
      'back_end' => '仅后台'
    }
    Spree.admin.tables.get(:shipping_methods).update(
      :display_on,
      method: ->(shipping_method) { display_on_labels.fetch(shipping_method.display_on.presence || 'both') }
    )
  end

  if Spree.admin.tables.registered?(:reimbursement_types)
    reimbursement_type_labels = {
      'Exchange' => '换货',
      'OriginalPayment' => '原路退款',
      'StoreCredit' => '储值金'
    }
    Spree.admin.tables.get(:reimbursement_types).update(
      :name,
      method: ->(reimbursement_type) { reimbursement_type.name }
    )
    Spree.admin.tables.get(:reimbursement_types).update(
      :type,
      method: ->(reimbursement_type) { reimbursement_type_labels.fetch(reimbursement_type.type.demodulize, reimbursement_type.type.demodulize) }
    )
  end
end
