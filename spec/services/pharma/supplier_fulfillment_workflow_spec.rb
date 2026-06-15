# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pharma::SupplierFulfillmentWorkflow do
  def supplier
    Pharma::Supplier.create!(
      name: '华东医药供货有限公司',
      code: 'SUP-FLOW-001',
      contact_name: '李经理',
      contact_phone: '13900010001',
      province: '上海市',
      city: '上海市',
      status: 'approved'
    )
  end

  def warehouse_for(supplier)
    Pharma::SupplierWarehouse.create!(
      supplier: supplier,
      name: '上海中心仓',
      code: 'WH-FLOW-001',
      province: '上海市',
      city: '上海市',
      address: '仓库路 10 号',
      status: 'active'
    )
  end

  def drug
    Pharma::DrugMaster.create!(
      common_name: '阿莫西林胶囊',
      specification: '0.25g*24粒',
      dosage_form: '胶囊剂',
      manufacturer: '示例制药有限公司',
      approval_number: '国药准字HFLOW001',
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
      batch_no: 'BATCH-FLOW-001',
      expiry_date: Date.current + 2.years,
      quantity_on_hand: 100,
      quantity_locked: 10,
      status: 'active'
    )
  end

  def spree_order
    store = Spree::Store.default

    Spree::Order.create!(
      number: 'RFLOW001',
      email: 'rflow001@example.com',
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
      fulfillment_no: 'FUL-RFLOW001-1-1',
      status: fulfillment_status
    )

    { fulfillment: fulfillment, allocation: allocation, stock: stock }
  end

  it 'moves a pending fulfillment into picking' do
    setup = fulfillment_setup

    fulfillment = described_class.new.call(fulfillment: setup.fetch(:fulfillment), event: 'start_picking')

    expect(fulfillment).to have_attributes(status: 'picking', shipped_at: nil, received_at: nil)
    expect(setup.fetch(:allocation).reload.status).to eq('allocated')
  end

  it 'ships a pending fulfillment and confirms related allocations' do
    setup = fulfillment_setup

    fulfillment = described_class.new.call(
      fulfillment: setup.fetch(:fulfillment),
      event: 'ship',
      delivery_company: '顺丰速运',
      delivery_tracking_no: 'SF123456'
    )

    expect(fulfillment).to have_attributes(
      status: 'shipped',
      delivery_company: '顺丰速运',
      delivery_tracking_no: 'SF123456'
    )
    expect(fulfillment.shipped_at).to be_present
    expect(setup.fetch(:allocation).reload.status).to eq('confirmed')
  end

  it 'receives a shipped fulfillment and fulfills related allocations' do
    setup = fulfillment_setup(allocation_status: 'confirmed', fulfillment_status: 'shipped')

    fulfillment = described_class.new.call(fulfillment: setup.fetch(:fulfillment), event: 'receive')

    expect(fulfillment).to have_attributes(status: 'received')
    expect(fulfillment.received_at).to be_present
    expect(setup.fetch(:allocation).reload.status).to eq('fulfilled')
    expect(setup.fetch(:stock).reload).to have_attributes(
      quantity_on_hand: 90,
      quantity_locked: 0
    )
  end

  it 'cancels an open fulfillment, cancels allocations, and releases locked stock' do
    setup = fulfillment_setup

    fulfillment = described_class.new.call(fulfillment: setup.fetch(:fulfillment), event: 'cancel')

    expect(fulfillment.status).to eq('canceled')
    expect(setup.fetch(:allocation).reload.status).to eq('canceled')
    expect(setup.fetch(:stock).reload.quantity_locked).to eq(0)
  end

  it 'rejects invalid transitions without changing persisted data' do
    setup = fulfillment_setup(allocation_status: 'fulfilled', fulfillment_status: 'received')

    expect do
      described_class.new.call(fulfillment: setup.fetch(:fulfillment), event: 'ship')
    end.to raise_error(Pharma::SupplierFulfillmentWorkflow::WorkflowError) { |error|
      expect(error.code).to eq('invalid_transition')
    }

    expect(setup.fetch(:fulfillment).reload.status).to eq('received')
    expect(setup.fetch(:allocation).reload.status).to eq('fulfilled')
  end
end
