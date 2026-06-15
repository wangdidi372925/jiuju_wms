# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pharma fulfillment models', type: :model do
  def supplier(code: 'SUP-FUL-001')
    Pharma::Supplier.create!(
      name: '华东医药供货有限公司',
      code: code,
      contact_name: '李经理',
      contact_phone: "139#{code.gsub(/\D/, '').last(8).rjust(8, '0')}",
      province: '上海市',
      city: '上海市',
      status: 'approved'
    )
  end

  def warehouse_for(supplier, code: 'WH-FUL-001')
    Pharma::SupplierWarehouse.create!(
      supplier: supplier,
      name: '上海中心仓',
      code: code,
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
      approval_number: '国药准字H00000002',
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

  def stock_for(supplier:, warehouse:, drug:, offer:, batch_no: 'BATCH-FUL-001')
    Pharma::DrugBatchStock.create!(
      supplier: supplier,
      supplier_warehouse: warehouse,
      drug_master: drug,
      supplier_offer: offer,
      batch_no: batch_no,
      expiry_date: Date.current + 2.years,
      quantity_on_hand: 100,
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

  def allocation_attributes(order:, line_item:, supplier:, warehouse:, stock:)
    {
      spree_order_id: order.id,
      spree_line_item_id: line_item.id,
      supplier: supplier,
      supplier_warehouse: warehouse,
      supplier_offer: stock.supplier_offer,
      drug_batch_stock: stock,
      supplier_name_snapshot: supplier.name,
      batch_no_snapshot: stock.batch_no,
      expiry_date_snapshot: stock.expiry_date,
      allocated_unit_price: 8.5,
      allocated_quantity: 10,
      status: 'allocated'
    }
  end

  it 'stores allocation snapshots needed for hidden supplier storefront mode' do
    supplier = supplier()
    warehouse = warehouse_for(supplier)
    drug = drug()
    offer = offer_for(supplier: supplier, warehouse: warehouse, drug: drug)
    stock = stock_for(supplier: supplier, warehouse: warehouse, drug: drug, offer: offer)
    order = spree_order(number: 'R1001')
    line_item = spree_line_item(order: order)

    allocation = Pharma::OrderAllocation.create!(
      allocation_attributes(
        order: order,
        line_item: line_item,
        supplier: supplier,
        warehouse: warehouse,
        stock: stock
      )
    )

    expect(allocation.total_amount).to eq(BigDecimal('85.0'))
    expect(allocation.supplier_name_snapshot).to eq('华东医药供货有限公司')
  end

  it 'requires allocation supplier, warehouse, and offer to match the selected batch stock' do
    supplier = supplier()
    warehouse = warehouse_for(supplier)
    drug = drug()
    offer = offer_for(supplier: supplier, warehouse: warehouse, drug: drug)
    stock = stock_for(supplier: supplier, warehouse: warehouse, drug: drug, offer: offer)
    other_supplier = supplier(code: 'SUP-FUL-OTHER')
    other_warehouse = warehouse_for(other_supplier, code: 'WH-FUL-OTHER')
    order = spree_order(number: 'R1002')
    line_item = spree_line_item(order: order)

    allocation = Pharma::OrderAllocation.new(
      allocation_attributes(
        order: order,
        line_item: line_item,
        supplier: other_supplier,
        warehouse: other_warehouse,
        stock: stock
      )
    )

    expect(allocation).not_to be_valid
    expect(allocation.errors[:supplier]).to include('must match drug_batch_stock')
    expect(allocation.errors[:supplier_warehouse]).to include('must match drug_batch_stock')
  end

  it 'requires allocation line item to belong to the allocation order' do
    supplier = supplier()
    warehouse = warehouse_for(supplier)
    drug = drug()
    offer = offer_for(supplier: supplier, warehouse: warehouse, drug: drug)
    stock = stock_for(supplier: supplier, warehouse: warehouse, drug: drug, offer: offer)
    order = spree_order(number: 'R1003')
    other_order = spree_order(number: 'R1004')
    line_item = spree_line_item(order: other_order)

    allocation = Pharma::OrderAllocation.new(
      allocation_attributes(
        order: order,
        line_item: line_item,
        supplier: supplier,
        warehouse: warehouse,
        stock: stock
      )
    )

    expect(allocation).not_to be_valid
    expect(allocation.errors[:spree_line_item]).to include('must belong to spree_order')
  end

  it 'requires fulfillment warehouse to belong to the fulfillment supplier' do
    supplier = supplier()
    other_supplier = supplier(code: 'SUP-FUL-FILL')
    other_warehouse = warehouse_for(other_supplier, code: 'WH-FUL-FILL')
    order = spree_order(number: 'R1005')

    fulfillment = Pharma::SupplierFulfillment.new(
      spree_order_id: order.id,
      supplier: supplier,
      supplier_warehouse: other_warehouse,
      fulfillment_no: 'FUL-001',
      status: 'pending'
    )

    expect(fulfillment).not_to be_valid
    expect(fulfillment.errors[:supplier_warehouse]).to include('must belong to supplier')
  end

  it 'requires fulfillment order to exist' do
    supplier = supplier()
    warehouse = warehouse_for(supplier)

    fulfillment = Pharma::SupplierFulfillment.new(
      spree_order_id: -1,
      supplier: supplier,
      supplier_warehouse: warehouse,
      fulfillment_no: 'FUL-002',
      status: 'pending'
    )

    expect(fulfillment).not_to be_valid
    expect(fulfillment.errors[:spree_order]).to include('must exist')
  end
end
