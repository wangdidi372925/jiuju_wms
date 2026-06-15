# frozen_string_literal: true

class LocalizeSpreeAdminSeedData < ActiveRecord::Migration[8.1]
  NAME_UPDATES = {
    spree_api_keys: { 'Default' => '默认' },
    spree_channels: { 'Online Store' => '在线店铺' },
    spree_countries: {
      'China' => '中国',
      'United States of America' => '美国'
    },
    spree_policies: {
      'Terms of Service' => '服务条款',
      'Privacy Policy' => '隐私政策',
      'Returns Policy' => '退换货政策',
      'Shipping Policy' => '配送政策'
    },
    spree_refund_reasons: { 'Return processing' => '退货处理' },
    spree_reimbursement_types: {
      'Exchange' => '换货',
      'Original payment' => '原路退款',
      'Store Credit' => '储值金'
    },
    spree_return_authorization_reasons: {
      'Accidental order' => '误下单',
      'Better price available' => '有更优价格',
      'Damaged/Defective' => '破损或质量问题',
      'Different from description' => '与描述不符',
      'Different from what was ordered' => '与订购商品不符',
      'Missed estimated delivery date' => '超过预计送达日期',
      'Missing parts or accessories' => '缺少部件或配件',
      'No longer needed/wanted' => '不再需要',
      'Unauthorized purchase' => '未经授权购买'
    },
    spree_shipping_categories: {
      'Default' => '默认配送',
      'Digital' => '数字商品'
    },
    spree_shipping_methods: {
      'Digital Delivery' => '数字配送'
    },
    spree_stock_locations: { 'Shop location' => '默认仓库' },
    spree_store_credit_categories: {
      'Default' => '默认',
      'Non-expiring' => '长期有效',
      'Expiring' => '有有效期'
    },
    spree_tax_categories: {
      'Default' => '默认税类',
      'Non-taxable' => '免税'
    },
    spree_zones: {
      'EU_VAT' => '欧盟增值税区',
      'UK_VAT' => '英国增值税区',
      'North America' => '北美',
      'Central America and Caribbean' => '中美洲和加勒比',
      'South America' => '南美',
      'Middle East' => '中东',
      'Africa' => '非洲',
      'Asia' => '亚洲',
      'Australia and Oceania' => '澳大利亚和大洋洲'
    }
  }.freeze

  DESCRIPTION_UPDATES = {
    spree_zones: {
      'Countries that make up the EU VAT zone.' => '欧盟增值税区域包含的国家。'
    }
  }.freeze

  def up
    NAME_UPDATES.each { |table, values| update_column_values(table, :name, values) }
    DESCRIPTION_UPDATES.each { |table, values| update_column_values(table, :description, values) }

    update_column_values(:spree_payment_methods, :name, 'Store Credit' => '储值金')
    update_column_values(:spree_payment_methods, :description, 'Store Credit' => '储值金')
  end

  def down
    NAME_UPDATES.each { |table, values| update_column_values(table, :name, values.invert) }
    DESCRIPTION_UPDATES.each { |table, values| update_column_values(table, :description, values.invert) }

    update_column_values(:spree_payment_methods, :name, '储值金' => 'Store Credit')
    update_column_values(:spree_payment_methods, :description, '储值金' => 'Store Credit')
  end

  private

  def update_column_values(table, column, values)
    return unless table_exists?(table) && column_exists?(table, column)

    values.each do |from, to|
      execute <<~SQL.squish
        UPDATE #{quote_table_name(table)}
        SET #{quote_column_name(column)} = #{quote(to)}
        #{updated_at_clause(table)}
        WHERE #{quote_column_name(column)} = #{quote(from)}
      SQL
    end
  end

  def updated_at_clause(table)
    return '' unless column_exists?(table, :updated_at)

    ", updated_at = #{quote(Time.current)}"
  end
end
