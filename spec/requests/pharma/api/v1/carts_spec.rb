# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pharma pharmacy carts API', type: :request do
  def json_body
    JSON.parse(response.body)
  end

  def approved_pharmacy(code: 'PH-CART-API-001')
    Pharma::Pharmacy.create!(
      name: '九州一号药店',
      code: code,
      contact_name: '王店长',
      contact_phone: '13800013001',
      province: '上海市',
      city: '上海市',
      district: '浦东新区',
      address: '张江路 13 号',
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

  def pending_pharmacy
    Pharma::Pharmacy.create!(
      name: '待审药店',
      code: 'PH-CART-API-PENDING',
      contact_name: '赵店长',
      contact_phone: '13800013002',
      province: '上海市',
      city: '上海市',
      district: '浦东新区',
      address: '张江路 14 号',
      status: 'pending'
    )
  end

  def approved_supplier
    Pharma::Supplier.create!(
      name: '华东医药供货有限公司',
      code: 'SUP-CART-API-001',
      contact_name: '李经理',
      contact_phone: '13900013001',
      province: '上海市',
      city: '上海市',
      status: 'approved',
      priority: 10
    ).tap do |supplier|
      Pharma::SupplierLicense.create!(
        supplier: supplier,
        license_type: 'drug_wholesale_license',
        license_no: 'SUP-CART-API-LICENSE-001',
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
      code: 'WH-CART-API-001',
      province: '上海市',
      city: '上海市',
      address: '仓库路 13 号',
      status: 'active'
    )
  end

  def drug
    Pharma::DrugMaster.create!(
      common_name: '阿莫西林胶囊',
      specification: '0.25g*24粒',
      dosage_form: '胶囊剂',
      manufacturer: '示例制药有限公司',
      approval_number: '国药准字HCARTAPI001',
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
      batch_no: 'BATCH-CART-API-001',
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

  it 'creates and shows a cart for an approved pharmacy' do
    pharmacy = approved_pharmacy

    post '/pharma/api/v1/carts',
         params: { pharmacy_code: pharmacy.code, email: 'buyer@example.com' }

    expect(response).to have_http_status(:created)
    data = json_body.fetch('data')
    expect(data).to include(
      'email' => 'buyer@example.com',
      'state' => 'cart',
      'status' => 'draft',
      'item_count' => 0,
      'items' => []
    )

    get "/pharma/api/v1/carts/#{data.fetch('number')}", params: { pharmacy_code: pharmacy.code }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch('data')).to include('number' => data.fetch('number'), 'items' => [])
  end

  it 'returns an error when pharmacy cannot purchase' do
    pharmacy = pending_pharmacy

    post '/pharma/api/v1/carts', params: { pharmacy_code: pharmacy.code }

    expect(response).to have_http_status(422)
    expect(json_body).to include('error' => 'pharmacy_not_allowed')
  end

  it 'adds a drug item and checks out the cart' do
    pharmacy = approved_pharmacy
    setup = stock_setup

    post '/pharma/api/v1/carts', params: { pharmacy_code: pharmacy.code }
    number = json_body.dig('data', 'number')

    post "/pharma/api/v1/carts/#{number}/items",
         params: {
           pharmacy_code: pharmacy.code,
           drug_master_id: setup.fetch(:drug).id,
           quantity: 10,
           province: '上海市',
           city: '上海市'
         }

    expect(response).to have_http_status(:created)
    expect(json_body.dig('data', 'items')).to contain_exactly(
      hash_including(
        'drug_master_id' => setup.fetch(:drug).id,
        'supplier_offer_id' => setup.fetch(:offer).id,
        'quantity' => 10,
        'unit_price' => '8.5'
      )
    )
    expect(setup.fetch(:stock).reload.quantity_locked).to eq(0)

    post "/pharma/api/v1/carts/#{number}/checkout", params: { pharmacy_code: pharmacy.code }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch('data')).to include('status' => 'placed', 'state' => 'complete')
    expect(json_body.dig('data', 'allocations')).to contain_exactly(
      hash_including('allocated_quantity' => 10, 'status' => 'allocated')
    )
    expect(setup.fetch(:stock).reload.quantity_locked).to eq(10)
  end

  it 'rejects checkout for an empty cart' do
    pharmacy = approved_pharmacy

    post '/pharma/api/v1/carts', params: { pharmacy_code: pharmacy.code }
    number = json_body.dig('data', 'number')

    post "/pharma/api/v1/carts/#{number}/checkout", params: { pharmacy_code: pharmacy.code }

    expect(response).to have_http_status(422)
    expect(json_body).to include('error' => 'empty_cart')
  end
end
