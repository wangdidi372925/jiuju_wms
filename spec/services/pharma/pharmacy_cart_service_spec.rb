# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pharma::PharmacyCartService do
  def approved_pharmacy(code: 'PH-CART-001')
    Pharma::Pharmacy.create!(
      name: '九州一号药店',
      code: code,
      contact_name: '王店长',
      contact_phone: '13800012001',
      province: '上海市',
      city: '上海市',
      district: '浦东新区',
      address: '张江路 12 号',
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
      code: 'PH-CART-PENDING',
      contact_name: '赵店长',
      contact_phone: '13800012002',
      province: '上海市',
      city: '上海市',
      district: '浦东新区',
      address: '张江路 13 号',
      status: 'pending'
    )
  end

  def approved_supplier
    Pharma::Supplier.create!(
      name: '华东医药供货有限公司',
      code: 'SUP-CART-001',
      contact_name: '李经理',
      contact_phone: '13900012001',
      province: '上海市',
      city: '上海市',
      status: 'approved',
      priority: 10
    ).tap do |supplier|
      Pharma::SupplierLicense.create!(
        supplier: supplier,
        license_type: 'drug_wholesale_license',
        license_no: 'SUP-CART-LICENSE-001',
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
      code: 'WH-CART-001',
      province: '上海市',
      city: '上海市',
      address: '仓库路 12 号',
      status: 'active'
    )
  end

  def drug
    Pharma::DrugMaster.create!(
      common_name: '阿莫西林胶囊',
      specification: '0.25g*24粒',
      dosage_form: '胶囊剂',
      manufacturer: '示例制药有限公司',
      approval_number: '国药准字HCART001',
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

  def stock_for(supplier:, warehouse:, drug:, offer:, quantity_on_hand: 100)
    Pharma::DrugBatchStock.create!(
      supplier: supplier,
      supplier_warehouse: warehouse,
      drug_master: drug,
      supplier_offer: offer,
      batch_no: 'BATCH-CART-001',
      expiry_date: Date.current + 2.years,
      quantity_on_hand: quantity_on_hand,
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

  it 'creates a cart for an approved pharmacy' do
    pharmacy = approved_pharmacy

    order = described_class.new.create_cart(pharmacy_code: pharmacy.code, email: 'buyer@example.com')

    expect(order).to have_attributes(
      email: 'buyer@example.com',
      locale: 'zh-CN',
      state: 'cart',
      status: 'draft',
      item_count: 0
    )
    expect(order.private_metadata).to include('pharmacy_id' => pharmacy.id, 'pharmacy_code' => pharmacy.code)
  end

  it 'rejects cart creation when the pharmacy cannot purchase' do
    pharmacy = pending_pharmacy

    expect do
      described_class.new.create_cart(pharmacy_code: pharmacy.code)
    end.to raise_error(Pharma::PharmacyCartService::CartError) { |error|
      expect(error.code).to eq('pharmacy_not_allowed')
    }
  end

  it 'adds a matched drug offer as a cart line item without locking stock' do
    pharmacy = approved_pharmacy
    setup = stock_setup
    order = described_class.new.create_cart(pharmacy_code: pharmacy.code)

    line_item = described_class.new.add_item(
      order_number: order.number,
      pharmacy_code: pharmacy.code,
      drug_master_id: setup.fetch(:drug).id,
      quantity: 10,
      province: '上海市',
      city: '上海市'
    )

    expect(line_item).to have_attributes(order_id: order.id, quantity: 10)
    expect(line_item.price.to_s).to eq('8.5')
    expect(line_item.private_metadata).to include(
      'drug_master_id' => setup.fetch(:drug).id,
      'supplier_offer_id' => setup.fetch(:offer).id,
      'drug_batch_stock_id' => setup.fetch(:stock).id
    )
    expect(order.reload).to have_attributes(item_count: 10)
    expect(order.item_total.to_s).to eq('85.0')
    expect(setup.fetch(:stock).reload.quantity_locked).to eq(0)
  end

  it 'rejects checkout for an empty cart' do
    pharmacy = approved_pharmacy
    order = described_class.new.create_cart(pharmacy_code: pharmacy.code)

    expect do
      described_class.new.checkout(order_number: order.number, pharmacy_code: pharmacy.code)
    end.to raise_error(Pharma::PharmacyCartService::CartError) { |error|
      expect(error.code).to eq('empty_cart')
    }
  end

  it 'checks out a cart by allocating stock and creating supplier fulfillment' do
    pharmacy = approved_pharmacy
    setup = stock_setup
    service = described_class.new
    order = service.create_cart(pharmacy_code: pharmacy.code)
    service.add_item(
      order_number: order.number,
      pharmacy_code: pharmacy.code,
      drug_master_id: setup.fetch(:drug).id,
      quantity: 10,
      province: '上海市',
      city: '上海市'
    )

    result = service.checkout(order_number: order.number, pharmacy_code: pharmacy.code)

    expect(result.order).to have_attributes(status: 'placed', state: 'complete')
    expect(result.order.completed_at).to be_present
    expect(result.allocations.first).to have_attributes(
      supplier_offer: setup.fetch(:offer),
      drug_batch_stock: setup.fetch(:stock),
      allocated_quantity: 10,
      status: 'allocated'
    )
    expect(result.fulfillments.first).to have_attributes(
      supplier: setup.fetch(:supplier),
      supplier_warehouse: setup.fetch(:warehouse),
      status: 'pending'
    )
    expect(setup.fetch(:stock).reload.quantity_locked).to eq(10)
  end
end
