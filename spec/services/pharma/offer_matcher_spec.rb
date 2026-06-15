# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pharma::OfferMatcher do
  def approved_supplier(code:, priority:)
    Pharma::Supplier.create!(
      name: "供应商#{code}",
      code: code,
      contact_name: '李经理',
      contact_phone: "139#{priority.to_s.rjust(8, '0')}",
      province: '上海市',
      city: '上海市',
      status: 'approved',
      priority: priority
    ).tap do |supplier|
      Pharma::SupplierLicense.create!(
        supplier: supplier,
        license_type: 'drug_wholesale_license',
        license_no: "LICENSE-#{code}",
        status: 'approved',
        starts_on: Date.current - 1.day,
        expires_on: Date.current + 1.year
      )
    end
  end

  def warehouse_for(supplier, code)
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

  let(:pharmacy) do
    Pharma::Pharmacy.create!(
      name: '九州一号药店',
      code: 'PH-MATCH-001',
      contact_name: '王店长',
      contact_phone: '13800000005',
      province: '上海市',
      city: '上海市',
      district: '浦东新区',
      address: '张江路 5 号',
      status: 'approved'
    ).tap do |record|
      Pharma::PharmacyLicense.create!(
        pharmacy: record,
        license_type: 'drug_business_license',
        license_no: 'PH-MATCH-LICENSE-001',
        status: 'approved',
        starts_on: Date.current - 1.day,
        expires_on: Date.current + 1.year
      )
    end
  end

  let(:drug) do
    Pharma::DrugMaster.create!(
      common_name: '阿莫西林胶囊',
      specification: '0.25g*24粒',
      dosage_form: '胶囊剂',
      manufacturer: '示例制药有限公司',
      approval_number: '国药准字H00000003',
      package_unit: '盒',
      storage_condition: '常温',
      temperature_control: 'normal'
    )
  end

  it 'returns only available offers sorted by price, supplier priority, and delivery days' do
    expensive_supplier = approved_supplier(code: 'SUP-MATCH-001', priority: 1)
    cheap_supplier = approved_supplier(code: 'SUP-MATCH-002', priority: 10)

    expensive_warehouse = warehouse_for(expensive_supplier, 'WH-MATCH-001')
    cheap_warehouse = warehouse_for(cheap_supplier, 'WH-MATCH-002')

    expensive_offer = Pharma::SupplierOffer.create!(
      supplier: expensive_supplier,
      drug_master: drug,
      supplier_warehouse: expensive_warehouse,
      unit_price: 9.0,
      min_order_quantity: 1,
      status: 'approved',
      starts_at: 1.day.ago,
      ends_at: 30.days.from_now
    )
    cheap_offer = Pharma::SupplierOffer.create!(
      supplier: cheap_supplier,
      drug_master: drug,
      supplier_warehouse: cheap_warehouse,
      unit_price: 8.5,
      min_order_quantity: 1,
      status: 'approved',
      starts_at: 1.day.ago,
      ends_at: 30.days.from_now
    )

    [expensive_offer, cheap_offer].each_with_index do |offer, index|
      Pharma::SupplierOfferRegion.create!(
        supplier_offer: offer,
        province: '上海市',
        city: '上海市',
        delivery_days: index + 1,
        status: 'active'
      )
      Pharma::DrugBatchStock.create!(
        supplier: offer.supplier,
        supplier_warehouse: offer.supplier_warehouse,
        drug_master: drug,
        supplier_offer: offer,
        batch_no: "BATCH-MATCH-#{index}",
        expiry_date: Date.current + 2.years,
        quantity_on_hand: 100,
        quantity_locked: 0,
        status: 'active'
      )
    end

    result = described_class.new.call(
      drug_master: drug,
      pharmacy: pharmacy,
      quantity: 10,
      province: '上海市',
      city: '上海市'
    )

    expect(result).to eq([cheap_offer, expensive_offer])
  end
end
