# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pharma admin order allocations API', type: :request do
  def json_body
    JSON.parse(response.body)
  end

  def admin_headers
    { 'X-Pharma-Admin-Token' => 'dev-admin-token' }
  end

  def supplier
    Pharma::Supplier.create!(
      name: '华东医药供货有限公司',
      code: 'SUP-ALLOC-API-001',
      contact_name: '李经理',
      contact_phone: '13900003001',
      province: '上海市',
      city: '上海市',
      status: 'approved'
    ).tap do |record|
      Pharma::SupplierLicense.create!(
        supplier: record,
        license_type: 'drug_wholesale_license',
        license_no: 'SUP-ALLOC-API-LICENSE-001',
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
      code: 'WH-ALLOC-API-001',
      province: '上海市',
      city: '上海市',
      address: '仓库路 3 号',
      status: 'active'
    )
  end

  def drug
    Pharma::DrugMaster.create!(
      common_name: '阿莫西林胶囊',
      specification: '0.25g*24粒',
      dosage_form: '胶囊剂',
      manufacturer: '示例制药有限公司',
      approval_number: '国药准字HALLOCAPI001',
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
    )
  end

  def stock_for(supplier:, warehouse:, drug:, offer:, quantity_on_hand: 100)
    Pharma::DrugBatchStock.create!(
      supplier: supplier,
      supplier_warehouse: warehouse,
      drug_master: drug,
      supplier_offer: offer,
      batch_no: 'BATCH-ALLOC-API-001',
      expiry_date: Date.current + 2.years,
      quantity_on_hand: quantity_on_hand,
      quantity_locked: 0,
      status: 'active'
    )
  end

  def spree_order(number:)
    store = Spree::Store.default

    Spree::Order.create!(
      number: number,
      email: "#{number.downcase}@example.com",
      store: store,
      currency: store.default_currency,
      locale: store.default_locale,
      state: 'cart'
    )
  end

  def spree_line_item(order:)
    result = Spree::LineItem.insert!(
      {
        order_id: order.id,
        quantity: 1,
        price: 8.5,
        currency: order.currency,
        created_at: Time.current,
        updated_at: Time.current
      },
      returning: %w[id]
    )

    Spree::LineItem.find(result.rows.first.first)
  end

  def allocation_payload(quantity_on_hand: 100, quantity: 10)
    supplier = supplier()
    warehouse = warehouse_for(supplier)
    drug = drug()
    offer = offer_for(supplier: supplier, warehouse: warehouse, drug: drug)
    stock = stock_for(supplier: supplier, warehouse: warehouse, drug: drug, offer: offer, quantity_on_hand: quantity_on_hand)
    order = spree_order(number: 'R3001')
    line_item = spree_line_item(order: order)

    {
      params: {
        spree_order_id: order.id,
        spree_line_item_id: line_item.id,
        supplier_offer_id: offer.id,
        drug_batch_stock_id: stock.id,
        quantity: quantity
      },
      stock: stock
    }
  end

  it 'requires an admin API token' do
    post '/pharma/admin/api/v1/order_allocations'

    expect(response).to have_http_status(:unauthorized)
    expect(json_body).to include('error' => 'unauthorized')
  end

  it 'creates an allocation and fulfillment' do
    payload = allocation_payload

    post '/pharma/admin/api/v1/order_allocations',
         params: payload.fetch(:params),
         headers: admin_headers

    expect(response).to have_http_status(:created)
    expect(json_body.fetch('data')).to include(
      'allocation' => hash_including(
        'allocated_quantity' => 10,
        'status' => 'allocated',
        'batch_no' => 'BATCH-ALLOC-API-001'
      ),
      'fulfillment' => hash_including(
        'status' => 'pending'
      )
    )
    expect(payload.fetch(:stock).reload.quantity_locked).to eq(10)
  end

  it 'returns not found when a referenced record is missing' do
    payload = allocation_payload

    post '/pharma/admin/api/v1/order_allocations',
         params: payload.fetch(:params).merge(supplier_offer_id: -1),
         headers: admin_headers

    expect(response).to have_http_status(:not_found)
    expect(json_body).to include('error' => 'not_found')
  end

  it 'returns an allocation error when stock is insufficient' do
    payload = allocation_payload(quantity_on_hand: 5, quantity: 10)

    post '/pharma/admin/api/v1/order_allocations',
         params: payload.fetch(:params),
         headers: admin_headers

    expect(response).to have_http_status(422)
    expect(json_body).to include('error' => 'insufficient_stock')
    expect(payload.fetch(:stock).reload.quantity_locked).to eq(0)
  end
end
