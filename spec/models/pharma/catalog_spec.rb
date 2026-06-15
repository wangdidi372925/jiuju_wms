# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pharma catalog models', type: :model do
  let(:supplier) do
    Pharma::Supplier.create!(
      name: '华东医药供货有限公司',
      code: 'SUP-CAT-001',
      contact_name: '李经理',
      contact_phone: '13900000002',
      province: '上海市',
      city: '上海市',
      status: 'approved',
      priority: 20
    ).tap do |record|
      Pharma::SupplierLicense.create!(
        supplier: record,
        license_type: 'drug_wholesale_license',
        license_no: '沪批发-CAT-001',
        status: 'approved',
        starts_on: Date.current - 30.days,
        expires_on: Date.current + 1.year
      )
    end
  end

  let(:warehouse) do
    Pharma::SupplierWarehouse.create!(
      supplier: supplier,
      name: '上海中心仓',
      code: 'WH-CAT-001',
      province: '上海市',
      city: '上海市',
      district: '浦东新区',
      address: '仓库路 1 号',
      cold_chain_enabled: false,
      status: 'active'
    )
  end

  let(:drug) do
    Pharma::DrugMaster.create!(
      common_name: '阿莫西林胶囊',
      trade_name: '阿莫西林胶囊',
      specification: '0.25g*24粒',
      dosage_form: '胶囊剂',
      manufacturer: '示例制药有限公司',
      approval_number: '国药准字H00000001',
      package_unit: '盒',
      prescription_required: true,
      storage_condition: '常温',
      temperature_control: 'normal'
    )
  end

  def create_supplier(code:, name: "供应商#{code}")
    Pharma::Supplier.create!(
      name: name,
      code: code,
      contact_name: '李经理',
      contact_phone: "139#{code.gsub(/\D/, '').last(8).rjust(8, '0')}",
      province: '上海市',
      city: '上海市',
      status: 'approved',
      priority: 1
    )
  end

  def create_warehouse(supplier:, code:)
    Pharma::SupplierWarehouse.create!(
      supplier: supplier,
      name: "仓库#{code}",
      code: code,
      province: '上海市',
      city: '上海市',
      address: "仓库#{code}地址",
      status: 'active'
    )
  end

  it 'builds a readable drug display name' do
    expect(drug.display_name).to eq('阿莫西林胶囊 0.25g*24粒 示例制药有限公司')
  end

  it 'marks an offer available when supplier, region, warehouse, stock, and expiry all qualify' do
    offer = Pharma::SupplierOffer.create!(
      supplier: supplier,
      drug_master: drug,
      supplier_warehouse: warehouse,
      unit_price: 8.5,
      min_order_quantity: 10,
      status: 'approved',
      starts_at: 1.day.ago,
      ends_at: 30.days.from_now
    )

    Pharma::SupplierOfferRegion.create!(
      supplier_offer: offer,
      province: '上海市',
      city: '上海市',
      delivery_days: 1,
      status: 'active'
    )

    Pharma::DrugBatchStock.create!(
      supplier: supplier,
      supplier_warehouse: warehouse,
      drug_master: drug,
      supplier_offer: offer,
      batch_no: 'BATCH-001',
      expiry_date: Date.current + 2.years,
      quantity_on_hand: 100,
      quantity_locked: 20,
      status: 'active'
    )

    expect(offer.available_for?(province: '上海市', city: '上海市', quantity: 30)).to be(true)
    expect(offer.available_quantity).to eq(80)
  end

  it 'requires an offer warehouse to belong to the offer supplier' do
    other_supplier = create_supplier(code: 'SUP-CAT-OTHER')
    other_warehouse = create_warehouse(supplier: other_supplier, code: 'WH-CAT-OTHER')

    offer = Pharma::SupplierOffer.new(
      supplier: supplier,
      drug_master: drug,
      supplier_warehouse: other_warehouse,
      unit_price: 8.5,
      min_order_quantity: 10,
      status: 'approved',
      starts_at: 1.day.ago,
      ends_at: 30.days.from_now
    )

    expect(offer).not_to be_valid
    expect(offer.errors[:supplier_warehouse]).to include('必须属于该货盘方')
  end

  it 'requires batch stock supplier, warehouse, and drug to match the offer' do
    offer = Pharma::SupplierOffer.create!(
      supplier: supplier,
      drug_master: drug,
      supplier_warehouse: warehouse,
      unit_price: 8.5,
      min_order_quantity: 10,
      status: 'approved',
      starts_at: 1.day.ago,
      ends_at: 30.days.from_now
    )
    other_supplier = create_supplier(code: 'SUP-CAT-STOCK')
    other_warehouse = create_warehouse(supplier: other_supplier, code: 'WH-CAT-STOCK')

    stock = Pharma::DrugBatchStock.new(
      supplier: other_supplier,
      supplier_warehouse: other_warehouse,
      drug_master: drug,
      supplier_offer: offer,
      batch_no: 'BATCH-MISMATCH',
      expiry_date: Date.current + 2.years,
      quantity_on_hand: 100,
      quantity_locked: 0,
      status: 'active'
    )

    expect(stock).not_to be_valid
    expect(stock.errors[:supplier]).to include('必须与货盘报价一致')
    expect(stock.errors[:supplier_warehouse]).to include('必须与货盘报价一致')
  end
end
