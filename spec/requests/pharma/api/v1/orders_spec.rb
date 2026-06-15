# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pharma pharmacy orders API', type: :request do
  def json_body
    JSON.parse(response.body)
  end

  def approved_pharmacy(code:, name:)
    Pharma::Pharmacy.create!(
      name: name,
      code: code,
      contact_name: '王店长',
      contact_phone: '13800014001',
      province: '上海市',
      city: '上海市',
      district: '浦东新区',
      address: '张江路 14 号',
      status: 'approved'
    ).tap do |pharmacy|
      Pharma::PharmacyLicense.create!(
        pharmacy: pharmacy,
        license_type: 'drug_business_license',
        license_no: "#{code}-LICENSE",
        status: 'approved',
        starts_on: Date.current - 1.day,
        expires_on: Date.current + 1.year
      )
    end
  end

  def approved_supplier(code: nil)
    code ||= "SUP-ORDER-API-#{Pharma::Supplier.count + 1}"

    Pharma::Supplier.create!(
      name: '华东医药供货有限公司',
      code: code,
      contact_name: '李经理',
      contact_phone: '13900014001',
      province: '上海市',
      city: '上海市',
      status: 'approved',
      priority: 10
    ).tap do |supplier|
      Pharma::SupplierLicense.create!(
        supplier: supplier,
        license_type: 'drug_wholesale_license',
        license_no: "#{code}-LICENSE",
        status: 'approved',
        starts_on: Date.current - 1.day,
        expires_on: Date.current + 1.year
      )
    end
  end

  def warehouse_for(supplier)
    Pharma::SupplierWarehouse.create!(
      supplier: supplier,
      name: '上海中心仓',
      code: "WH-ORDER-API-#{supplier.id}",
      province: '上海市',
      city: '上海市',
      address: '仓库路 14 号',
      status: 'active'
    )
  end

  def drug(approval_number: nil)
    approval_number ||= "国药准字HORDERAPI#{Pharma::DrugMaster.count + 1}"

    Pharma::DrugMaster.create!(
      common_name: '阿莫西林胶囊',
      specification: '0.25g*24粒',
      dosage_form: '胶囊剂',
      manufacturer: '示例制药有限公司',
      approval_number: approval_number,
      package_unit: '盒',
      storage_condition: '常温',
      temperature_control: 'normal'
    )
  end

  def offer_for(supplier:, warehouse:, drug:)
    Pharma::SupplierOffer.create!(
      supplier: supplier,
      drug_master: drug,
      supplier_warehouse: warehouse,
      unit_price: 8.5,
      min_order_quantity: 1,
      status: 'approved',
      starts_at: 1.day.ago,
      ends_at: 30.days.from_now
    ).tap do |offer|
      Pharma::SupplierOfferRegion.create!(
        supplier_offer: offer,
        province: '上海市',
        city: '上海市',
        delivery_days: 1,
        status: 'active'
      )
    end
  end

  def stock_for(supplier:, warehouse:, drug:, offer:)
    Pharma::DrugBatchStock.create!(
      supplier: supplier,
      supplier_warehouse: warehouse,
      drug_master: drug,
      supplier_offer: offer,
      batch_no: 'BATCH-ORDER-API-001',
      expiry_date: Date.current + 2.years,
      quantity_on_hand: 100,
      quantity_locked: 0,
      status: 'active'
    )
  end

  def stock_setup
    supplier = approved_supplier
    warehouse = warehouse_for(supplier)
    drug = drug()
    offer = offer_for(supplier: supplier, warehouse: warehouse, drug: drug)
    stock = stock_for(supplier: supplier, warehouse: warehouse, drug: drug, offer: offer)

    { supplier: supplier, warehouse: warehouse, drug: drug, offer: offer, stock: stock }
  end

  def submitted_order_for(pharmacy:, quantity: 10)
    setup = stock_setup
    service = Pharma::PharmacyCartService.new
    order = service.create_cart(pharmacy_code: pharmacy.code, email: "#{pharmacy.code.downcase}@example.com")
    service.add_item(
      order_number: order.number,
      pharmacy_code: pharmacy.code,
      drug_master_id: setup.fetch(:drug).id,
      quantity: quantity,
      province: '上海市',
      city: '上海市'
    )
    service.checkout(order_number: order.number, pharmacy_code: pharmacy.code).order.reload
  end

  def bearer_token_for(pharmacy:, email:)
    user = Spree::User.create!(
      email: email,
      password: 'Password123!',
      password_confirmation: 'Password123!'
    )
    pharmacy_user = Pharma::PharmacyUser.create!(
      pharmacy: pharmacy,
      user: user,
      role: 'buyer',
      status: 'active'
    )
    _token_record, raw_token = Pharma::PharmacyApiToken.issue!(pharmacy_user: pharmacy_user)

    "Bearer #{raw_token}"
  end

  it 'lists submitted orders for the requested pharmacy only' do
    pharmacy = approved_pharmacy(code: 'PH-ORDER-API-001', name: '九州一号药店')
    other_pharmacy = approved_pharmacy(code: 'PH-ORDER-API-002', name: '九州二号药店')
    submitted_order = submitted_order_for(pharmacy: pharmacy)
    submitted_order_for(pharmacy: other_pharmacy)
    Pharma::PharmacyCartService.new.create_cart(pharmacy_code: pharmacy.code)

    get '/pharma/api/v1/orders', params: { pharmacy_code: pharmacy.code }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch('data')).to contain_exactly(
      hash_including(
        'number' => submitted_order.number,
        'status' => 'placed',
        'state' => 'complete',
        'item_count' => 10,
        'total' => '85.0',
        'pharmacy' => hash_including('code' => pharmacy.code, 'name' => '九州一号药店'),
        'allocation_statuses' => ['allocated'],
        'fulfillment_statuses' => ['pending']
      )
    )
  end

  it 'lists submitted orders for the authenticated pharmacy token' do
    pharmacy = approved_pharmacy(code: 'PH-ORDER-API-TOKEN-001', name: '九州令牌一号药店')
    other_pharmacy = approved_pharmacy(code: 'PH-ORDER-API-TOKEN-002', name: '九州令牌二号药店')
    submitted_order = submitted_order_for(pharmacy: pharmacy)
    submitted_order_for(pharmacy: other_pharmacy)
    authorization = bearer_token_for(pharmacy: pharmacy, email: 'orders-token@example.com')

    get '/pharma/api/v1/orders', headers: { 'Authorization' => authorization }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch('data')).to contain_exactly(
      hash_including(
        'number' => submitted_order.number,
        'pharmacy' => hash_including('code' => pharmacy.code, 'name' => '九州令牌一号药店')
      )
    )
  end

  it 'shows order details with items, allocations, and fulfillments' do
    pharmacy = approved_pharmacy(code: 'PH-ORDER-API-003', name: '九州三号药店')
    order = submitted_order_for(pharmacy: pharmacy, quantity: 6)

    get "/pharma/api/v1/orders/#{order.number}", params: { pharmacy_code: pharmacy.code }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch('data')).to include(
      'number' => order.number,
      'status' => 'placed',
      'completed_at' => be_present,
      'items' => [
        hash_including(
          'drug_name' => '阿莫西林胶囊 0.25g*24粒 示例制药有限公司',
          'quantity' => 6,
          'unit_price' => '8.5',
          'total' => '51.0'
        )
      ],
      'allocations' => [
        hash_including(
          'batch_no' => 'BATCH-ORDER-API-001',
          'allocated_quantity' => 6,
          'status' => 'allocated'
        )
      ],
      'fulfillments' => [
        hash_including(
          'fulfillment_no' => a_string_starting_with("FUL-#{order.number}"),
          'status' => 'pending',
          'supplier_name' => '华东医药供货有限公司',
          'warehouse_name' => '上海中心仓'
        )
      ]
    )
  end

  it 'does not show another pharmacy order' do
    pharmacy = approved_pharmacy(code: 'PH-ORDER-API-004', name: '九州四号药店')
    other_pharmacy = approved_pharmacy(code: 'PH-ORDER-API-005', name: '九州五号药店')
    other_order = submitted_order_for(pharmacy: other_pharmacy)

    get "/pharma/api/v1/orders/#{other_order.number}", params: { pharmacy_code: pharmacy.code }

    expect(response).to have_http_status(:not_found)
    expect(json_body).to include('error' => 'not_found')
  end
end
