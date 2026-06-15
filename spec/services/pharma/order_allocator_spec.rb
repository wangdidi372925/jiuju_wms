# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pharma::OrderAllocator do
  def supplier
    Pharma::Supplier.create!(
      name: '华东医药供货有限公司',
      code: 'SUP-ALLOC-001',
      contact_name: '李经理',
      contact_phone: '13900002001',
      province: '上海市',
      city: '上海市',
      status: 'approved'
    ).tap do |record|
      Pharma::SupplierLicense.create!(
        supplier: record,
        license_type: 'drug_wholesale_license',
        license_no: 'SUP-ALLOC-LICENSE-001',
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
      code: 'WH-ALLOC-001',
      province: '上海市',
      city: '上海市',
      address: '仓库路 2 号',
      status: 'active'
    )
  end

  def drug
    Pharma::DrugMaster.create!(
      common_name: '阿莫西林胶囊',
      specification: '0.25g*24粒',
      dosage_form: '胶囊剂',
      manufacturer: '示例制药有限公司',
      approval_number: '国药准字HALLOC001',
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
      batch_no: 'BATCH-ALLOC-001',
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

  it 'creates allocation, locks stock, and creates supplier fulfillment' do
    supplier = supplier()
    warehouse = warehouse_for(supplier)
    drug = drug()
    offer = offer_for(supplier: supplier, warehouse: warehouse, drug: drug)
    stock = stock_for(supplier: supplier, warehouse: warehouse, drug: drug, offer: offer)
    order = spree_order(number: 'R2001')
    line_item = spree_line_item(order: order)

    result = described_class.new.call(
      spree_order_id: order.id,
      spree_line_item_id: line_item.id,
      supplier_offer_id: offer.id,
      drug_batch_stock_id: stock.id,
      quantity: 10
    )

    expect(result.allocation).to have_attributes(
      spree_order_id: order.id,
      spree_line_item_id: line_item.id,
      supplier: supplier,
      supplier_warehouse: warehouse,
      supplier_offer: offer,
      drug_batch_stock: stock,
      supplier_name_snapshot: '华东医药供货有限公司',
      batch_no_snapshot: 'BATCH-ALLOC-001',
      allocated_quantity: 10,
      status: 'allocated'
    )
    expect(result.fulfillment).to have_attributes(
      spree_order_id: order.id,
      supplier: supplier,
      supplier_warehouse: warehouse,
      status: 'pending'
    )
    expect(stock.reload.quantity_locked).to eq(10)
  end

  it 'does not lock stock when available quantity is insufficient' do
    supplier = supplier()
    warehouse = warehouse_for(supplier)
    drug = drug()
    offer = offer_for(supplier: supplier, warehouse: warehouse, drug: drug)
    stock = stock_for(supplier: supplier, warehouse: warehouse, drug: drug, offer: offer, quantity_on_hand: 5)
    order = spree_order(number: 'R2002')
    line_item = spree_line_item(order: order)

    expect do
      described_class.new.call(
        spree_order_id: order.id,
        spree_line_item_id: line_item.id,
        supplier_offer_id: offer.id,
        drug_batch_stock_id: stock.id,
        quantity: 10
      )
    end.to raise_error(Pharma::OrderAllocator::AllocationError) { |error|
      expect(error.code).to eq('insufficient_stock')
    }

    expect(stock.reload.quantity_locked).to eq(0)
    expect(Pharma::OrderAllocation.count).to eq(0)
  end

  it 'rejects line items that do not belong to the order' do
    supplier = supplier()
    warehouse = warehouse_for(supplier)
    drug = drug()
    offer = offer_for(supplier: supplier, warehouse: warehouse, drug: drug)
    stock = stock_for(supplier: supplier, warehouse: warehouse, drug: drug, offer: offer)
    order = spree_order(number: 'R2003')
    other_order = spree_order(number: 'R2004')
    line_item = spree_line_item(order: other_order)

    expect do
      described_class.new.call(
        spree_order_id: order.id,
        spree_line_item_id: line_item.id,
        supplier_offer_id: offer.id,
        drug_batch_stock_id: stock.id,
        quantity: 10
      )
    end.to raise_error(Pharma::OrderAllocator::AllocationError) { |error|
      expect(error.code).to eq('line_item_order_mismatch')
    }
  end
end
