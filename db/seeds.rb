# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

Spree::Core::Engine.load_seed if defined?(Spree::Core)

def localize_seed_column(table, column, values)
  connection = ActiveRecord::Base.connection
  return unless connection.table_exists?(table) && connection.column_exists?(table, column)

  values.each do |from, to|
    updated_at = connection.column_exists?(table, :updated_at) ? ", updated_at = #{connection.quote(Time.current)}" : ''
    connection.execute <<~SQL.squish
      UPDATE #{connection.quote_table_name(table)}
      SET #{connection.quote_column_name(column)} = #{connection.quote(to)}
      #{updated_at}
      WHERE #{connection.quote_column_name(column)} = #{connection.quote(from)}
    SQL
  end
end

if defined?(Spree)
  {
    spree_api_keys: { 'Default' => '默认' },
    spree_channels: { 'Online Store' => '在线店铺' },
    spree_countries: { 'China' => '中国', 'United States of America' => '美国' },
    spree_policies: {
      'Terms of Service' => '服务条款',
      'Privacy Policy' => '隐私政策',
      'Returns Policy' => '退换货政策',
      'Shipping Policy' => '配送政策'
    },
    spree_refund_reasons: { 'Return processing' => '退货处理' },
    spree_reimbursement_types: { 'Exchange' => '换货', 'Original payment' => '原路退款', 'Store Credit' => '储值金' },
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
    spree_shipping_categories: { 'Default' => '默认配送', 'Digital' => '数字商品' },
    spree_shipping_methods: { 'Digital Delivery' => '数字配送' },
    spree_stock_locations: { 'Shop location' => '默认仓库' },
    spree_store_credit_categories: { 'Default' => '默认', 'Non-expiring' => '长期有效', 'Expiring' => '有有效期' },
    spree_tax_categories: { 'Default' => '默认税类', 'Non-taxable' => '免税' },
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
  }.each { |table, values| localize_seed_column(table, :name, values) }

  localize_seed_column(
    :spree_zones,
    :description,
    {
      'Countries that make up the EU VAT zone.' => '欧盟增值税区域包含的国家。',
      'USA + Canada' => '美国和加拿大',
      'Central America and Caribbean' => '中美洲和加勒比',
      'South America' => '南美',
      'Middle East' => '中东',
      'Africa' => '非洲',
      'Asia' => '亚洲',
      'Australia and Oceania' => '澳大利亚和大洋洲'
    }
  )
  localize_seed_column(:spree_payment_methods, :name, 'Store Credit' => '储值金')
  localize_seed_column(:spree_payment_methods, :description, 'Store Credit' => '储值金')
end

if defined?(Spree::Store)
  Spree::Store.find_each do |store|
    store.name = '九州药品采购平台' if ['Spree Test Store', 'Spree Demo Site', 'Spree Store'].include?(store.name)
    store.preferred_admin_locale = 'zh-CN' if store.preferred_admin_locale.blank? || store.preferred_admin_locale == 'en'
    store.preferred_timezone = 'Beijing' if store.preferred_timezone.blank? || store.preferred_timezone == 'UTC'
    store.update!(
      default_locale: 'zh-CN',
      supported_locales: 'zh-CN,en'
    )
  end
end

if defined?(Spree::AdminUser) && !Rails.env.production?
  admin_email = ENV.fetch('SPREE_ADMIN_EMAIL', 'spree@example.com')
  admin_password = ENV.fetch('SPREE_ADMIN_PASSWORD', 'spree123')
  admin_user = Spree.admin_user_class.find_or_initialize_by(email: admin_email)

  unless admin_user.persisted? && admin_user.valid_password?(admin_password)
    admin_user.password = admin_password
    admin_user.password_confirmation = admin_password
  end
  if admin_user.first_name.blank? || (admin_user.first_name == 'Spree' && admin_user.last_name == 'Admin')
    admin_user.first_name = '管理员'
    admin_user.last_name = nil
  end
  admin_user.save!

  admin_role = Spree::Role.find_or_create_by!(name: 'admin')
  admin_user.spree_roles << admin_role unless admin_user.spree_roles.exists?(admin_role.id)

  puts "Spree 管理员账号：#{admin_email} / #{admin_password}"
end

load Rails.root.join('db/seeds/pharma_demo.rb')
