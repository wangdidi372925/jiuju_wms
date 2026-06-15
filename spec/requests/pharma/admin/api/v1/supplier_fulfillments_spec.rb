# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pharma admin supplier fulfillments API', type: :request do
  def json_body
    JSON.parse(response.body)
  end

  def admin_headers
    { 'X-Pharma-Admin-Token' => 'dev-admin-token' }
  end

  def supplier(code: 'SUP-FLOW-API-001')
    Pharma::Supplier.create!(
      name: '华东医药供货有限公司',
      code: code,
      contact_name: '李经理',
      contact_phone: '13900011001',
      province: '上海市',
      city: '上海市',
      status: 'approved'
    )
  end

  def warehouse_for(supplier)
    Pharma::SupplierWarehouse.create!(
      supplier: supplier,
      name: '上海中心仓',
      code: 'WH-FLOW-API-001',
      province: '上海市',
      city: '上海市',
      address: '仓库路 11 号',
      status: 'active'
    )
  end

  def drug
    Pharma::DrugMaster.create!(
      common_name: '阿莫西林胶囊',
      specification: '0.25g*24粒',
      dosage_form: '胶囊剂',
      manufacturer: '示例制药有限公司',
      approval_number: '国药准字HFLOWAPI001',
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

  def stock_for(supplier:, warehouse:, drug:, offer:)
    Pharma::DrugBatchStock.create!(
      supplier: supplier,
      supplier_warehouse: warehouse,
      drug_master: drug,
      supplier_offer: offer,
      batch_no: 'BATCH-FLOW-API-001',
      expiry_date: Date.current + 2.years,
      quantity_on_hand: 100,
      quantity_locked: 10,
      status: 'active'
    )
  end

  def spree_order
    store = Spree::Store.default

    Spree::Order.create!(
      number: 'RFLOWAPI001',
      email: 'rflowapi001@example.com',
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

  def fulfillment_setup(allocation_status: 'allocated', fulfillment_status: 'pending')
    supplier = supplier()
    warehouse = warehouse_for(supplier)
    drug = drug()
    offer = offer_for(supplier: supplier, warehouse: warehouse, drug: drug)
    stock = stock_for(supplier: supplier, warehouse: warehouse, drug: drug, offer: offer)
    order = spree_order
    line_item = spree_line_item(order: order)

    allocation = Pharma::OrderAllocation.create!(
      spree_order_id: order.id,
      spree_line_item_id: line_item.id,
      supplier: supplier,
      supplier_warehouse: warehouse,
      supplier_offer: offer,
      drug_batch_stock: stock,
      supplier_name_snapshot: supplier.name,
      batch_no_snapshot: stock.batch_no,
      expiry_date_snapshot: stock.expiry_date,
      allocated_unit_price: offer.unit_price,
      allocated_quantity: 10,
      status: allocation_status
    )
    fulfillment = Pharma::SupplierFulfillment.create!(
      spree_order_id: order.id,
      supplier: supplier,
      supplier_warehouse: warehouse,
      fulfillment_no: 'FUL-RFLOWAPI001-1-1',
      status: fulfillment_status
    )

    { fulfillment: fulfillment, allocation: allocation, stock: stock }
  end

  it 'requires an admin API token' do
    get '/pharma/admin/api/v1/supplier_fulfillments'

    expect(response).to have_http_status(:unauthorized)
    expect(json_body).to include('error' => 'unauthorized')
  end

  it 'lists fulfillments with an optional status filter' do
    setup = fulfillment_setup(fulfillment_status: 'pending')

    get '/pharma/admin/api/v1/supplier_fulfillments',
        params: { status: 'pending' },
        headers: admin_headers

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch('data')).to contain_exactly(
      hash_including(
        'id' => setup.fetch(:fulfillment).id,
        'status' => 'pending',
        'supplier_name' => '华东医药供货有限公司',
        'warehouse_name' => '上海中心仓'
      )
    )
  end

  it 'shows fulfillment details with related allocations' do
    setup = fulfillment_setup

    get "/pharma/admin/api/v1/supplier_fulfillments/#{setup.fetch(:fulfillment).id}", headers: admin_headers

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch('data')).to include(
      'id' => setup.fetch(:fulfillment).id,
      'status' => 'pending',
      'allocations' => [
        hash_including(
          'id' => setup.fetch(:allocation).id,
          'status' => 'allocated',
          'batch_no' => 'BATCH-FLOW-API-001',
          'allocated_quantity' => 10
        )
      ]
    )
  end

  it 'transitions a fulfillment through the workflow' do
    setup = fulfillment_setup

    patch "/pharma/admin/api/v1/supplier_fulfillments/#{setup.fetch(:fulfillment).id}/transition",
          params: { event: 'ship', delivery_company: '顺丰速运', delivery_tracking_no: 'SF987654' },
          headers: admin_headers

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch('data')).to include(
      'status' => 'shipped',
      'delivery_company' => '顺丰速运',
      'delivery_tracking_no' => 'SF987654'
    )
    expect(json_body.dig('data', 'shipped_at')).to be_present
    expect(setup.fetch(:allocation).reload.status).to eq('confirmed')
  end

  it 'returns a workflow error for invalid transitions' do
    setup = fulfillment_setup(allocation_status: 'fulfilled', fulfillment_status: 'received')

    patch "/pharma/admin/api/v1/supplier_fulfillments/#{setup.fetch(:fulfillment).id}/transition",
          params: { event: 'ship' },
          headers: admin_headers

    expect(response).to have_http_status(422)
    expect(json_body).to include('error' => 'invalid_transition')
    expect(setup.fetch(:fulfillment).reload.status).to eq('received')
  end
end
