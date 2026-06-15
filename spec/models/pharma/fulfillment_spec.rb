# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pharma fulfillment models', type: :model do
  it 'stores allocation snapshots needed for hidden supplier storefront mode' do
    supplier = Pharma::Supplier.create!(
      name: '华东医药供货有限公司',
      code: 'SUP-FUL-001',
      contact_name: '李经理',
      contact_phone: '13900000003',
      province: '上海市',
      city: '上海市',
      status: 'approved'
    )
    warehouse = Pharma::SupplierWarehouse.create!(
      supplier: supplier,
      name: '上海中心仓',
      code: 'WH-FUL-001',
      province: '上海市',
      city: '上海市',
      address: '仓库路 2 号',
      status: 'active'
    )
    drug = Pharma::DrugMaster.create!(
      common_name: '阿莫西林胶囊',
      specification: '0.25g*24粒',
      dosage_form: '胶囊剂',
      manufacturer: '示例制药有限公司',
      approval_number: '国药准字H00000002',
      package_unit: '盒',
      storage_condition: '常温',
      temperature_control: 'normal'
    )
    offer = Pharma::SupplierOffer.create!(
      supplier: supplier,
      drug_master: drug,
      supplier_warehouse: warehouse,
      unit_price: 8.5,
      min_order_quantity: 1,
      status: 'approved',
      starts_at: 1.day.ago,
      ends_at: 30.days.from_now
    )
    stock = Pharma::DrugBatchStock.create!(
      supplier: supplier,
      supplier_warehouse: warehouse,
      drug_master: drug,
      supplier_offer: offer,
      batch_no: 'BATCH-FUL-001',
      expiry_date: Date.current + 2.years,
      quantity_on_hand: 100,
      quantity_locked: 0,
      status: 'active'
    )

    allocation = Pharma::OrderAllocation.create!(
      spree_order_id: 1001,
      spree_line_item_id: 2001,
      supplier: supplier,
      supplier_warehouse: warehouse,
      supplier_offer: offer,
      drug_batch_stock: stock,
      supplier_name_snapshot: supplier.name,
      batch_no_snapshot: stock.batch_no,
      expiry_date_snapshot: stock.expiry_date,
      allocated_unit_price: 8.5,
      allocated_quantity: 10,
      status: 'allocated'
    )

    expect(allocation.total_amount).to eq(BigDecimal('85.0'))
    expect(allocation.supplier_name_snapshot).to eq('华东医药供货有限公司')
  end
end
