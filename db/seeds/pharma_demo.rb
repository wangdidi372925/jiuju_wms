# frozen_string_literal: true

if Rails.env.production?
  Rails.logger.info('Skipping pharma demo seed in production')
else
  pharmacy = Pharma::Pharmacy.find_or_create_by!(code: 'PH-DEMO-001') do |record|
    record.name = '九州示例药店'
    record.contact_name = '王店长'
    record.contact_phone = '13800000888'
    record.province = '上海市'
    record.city = '上海市'
    record.district = '浦东新区'
    record.address = '张江路 88 号'
    record.status = 'approved'
  end

  Pharma::PharmacyLicense.find_or_create_by!(
    pharmacy: pharmacy,
    license_type: 'drug_business_license',
    license_no: '沪药营-DEMO-001'
  ) do |record|
    record.status = 'approved'
    record.starts_on = Date.current - 30.days
    record.expires_on = Date.current + 1.year
  end

  buyer_email = ENV.fetch('PHARMA_DEMO_BUYER_EMAIL', 'buyer@example.com')
  buyer_password = ENV.fetch('PHARMA_DEMO_BUYER_PASSWORD', 'buyer123')
  buyer = Spree::User.find_or_initialize_by(email: buyer_email)
  unless buyer.persisted? && buyer.valid_password?(buyer_password)
    buyer.password = buyer_password
    buyer.password_confirmation = buyer_password
  end
  buyer.save!

  Pharma::PharmacyUser.find_or_create_by!(pharmacy: pharmacy, user: buyer) do |record|
    record.role = 'buyer'
    record.status = 'active'
  end

  admin_api_token = ENV.fetch('PHARMA_DEMO_ADMIN_API_TOKEN', 'dev-admin-token')
  admin_api_client = Pharma::AdminApiClient.find_or_initialize_by(
    token_digest: Pharma::AdminApiClient.digest(admin_api_token)
  )
  admin_api_client.name = '开发默认后台 API 客户端'
  admin_api_client.token_prefix = admin_api_token.first(12)
  admin_api_client.role = 'super_admin'
  admin_api_client.status = 'active'
  admin_api_client.save!

  supplier = Pharma::Supplier.find_or_create_by!(code: 'SUP-DEMO-001') do |record|
    record.name = '华东医药供货有限公司'
    record.contact_name = '李经理'
    record.contact_phone = '13900000999'
    record.province = '上海市'
    record.city = '上海市'
    record.status = 'approved'
    record.priority = 10
  end

  Pharma::SupplierLicense.find_or_create_by!(
    supplier: supplier,
    license_type: 'drug_wholesale_license',
    license_no: '沪批发-DEMO-001'
  ) do |record|
    record.status = 'approved'
    record.starts_on = Date.current - 30.days
    record.expires_on = Date.current + 1.year
  end

  warehouse = Pharma::SupplierWarehouse.find_or_create_by!(code: 'WH-DEMO-001') do |record|
    record.supplier = supplier
    record.name = '上海中心仓'
    record.province = '上海市'
    record.city = '上海市'
    record.district = '浦东新区'
    record.address = '仓库路 8 号'
    record.status = 'active'
  end

  drug = Pharma::DrugMaster.find_or_create_by!(approval_number: '国药准字H00000001') do |record|
    record.common_name = '阿莫西林胶囊'
    record.trade_name = '阿莫西林胶囊'
    record.specification = '0.25g*24粒'
    record.dosage_form = '胶囊剂'
    record.manufacturer = '示例制药有限公司'
    record.package_unit = '盒'
    record.prescription_required = true
    record.storage_condition = '常温'
    record.temperature_control = 'normal'
    record.status = 'active'
  end

  offer = Pharma::SupplierOffer.find_or_create_by!(
    supplier: supplier,
    drug_master: drug,
    supplier_warehouse: warehouse
  ) do |record|
    record.unit_price = 8.5
    record.min_order_quantity = 10
    record.status = 'approved'
    record.starts_at = 1.day.ago
    record.ends_at = 30.days.from_now
  end

  Pharma::SupplierOfferRegion.find_or_create_by!(
    supplier_offer: offer,
    province: '上海市',
    city: '上海市',
    district: nil
  ) do |record|
    record.delivery_days = 1
    record.status = 'active'
  end

  Pharma::DrugBatchStock.find_or_create_by!(
    supplier: supplier,
    supplier_warehouse: warehouse,
    drug_master: drug,
    supplier_offer: offer,
    batch_no: 'DEMO-BATCH-001'
  ) do |record|
    record.expiry_date = Date.current + 2.years
    record.quantity_on_hand = 300
    record.quantity_locked = 0
    record.status = 'active'
  end

  Pharma::SupplierVisibilityConfig.current

  puts "药店买家账号：#{buyer_email} / #{buyer_password}，药店编码：#{pharmacy.code}"
  puts "后台 API 客户端：#{admin_api_client.name}，角色：#{admin_api_client.role}，Token：#{admin_api_token}"
end
