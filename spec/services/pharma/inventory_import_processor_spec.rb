# frozen_string_literal: true

require 'rails_helper'
require 'support/pharma_xlsx_fixture'

RSpec.describe Pharma::InventoryImportProcessor do
  include PharmaXlsxFixture

  HEADERS = [
    '供应商编码', '供应商名称', '供应商联系人', '供应商电话', '供应商省', '供应商市',
    '仓库编码', '仓库名称', '仓库省', '仓库市', '仓库区', '仓库地址',
    '通用名', '商品名', '规格', '剂型', '生产厂家', '批准文号', '包装单位',
    '是否处方', '储存条件', '温控', '单价', '起订量', '限购量',
    '报价状态', '报价开始', '报价结束', '可售省', '可售市', '可售区',
    '配送天数', '批号', '效期', '库存', '锁定库存'
  ].freeze

  def valid_row(overrides = {})
    values = {
      '供应商编码' => 'SUP-IMPORT-001',
      '供应商名称' => '华东医药供货有限公司',
      '供应商联系人' => '李经理',
      '供应商电话' => '13900008001',
      '供应商省' => '上海市',
      '供应商市' => '上海市',
      '仓库编码' => 'WH-IMPORT-001',
      '仓库名称' => '上海中心仓',
      '仓库省' => '上海市',
      '仓库市' => '上海市',
      '仓库区' => '浦东新区',
      '仓库地址' => '仓库路 8 号',
      '通用名' => '阿莫西林胶囊',
      '商品名' => '阿莫西林',
      '规格' => '0.25g*24粒',
      '剂型' => '胶囊剂',
      '生产厂家' => '示例制药有限公司',
      '批准文号' => '国药准字HIMPORT001',
      '包装单位' => '盒',
      '是否处方' => '是',
      '储存条件' => '常温',
      '温控' => '常温',
      '单价' => '8.5',
      '起订量' => '10',
      '限购量' => '500',
      '报价状态' => 'approved',
      '报价开始' => '2026-06-01',
      '报价结束' => '2026-12-31',
      '可售省' => '上海市',
      '可售市' => '上海市',
      '可售区' => '浦东新区',
      '配送天数' => '1',
      '批号' => 'BATCH-IMPORT-001',
      '效期' => '2028-06-01',
      '库存' => '300',
      '锁定库存' => '20'
    }.merge(overrides)

    HEADERS.map { |header| values.fetch(header) }
  end

  def build_inventory_file(rows)
    build_xlsx([HEADERS, *rows])
  end

  it 'imports supplier offers, regions, and batch stock from a valid workbook row' do
    file = build_inventory_file([valid_row])

    import = described_class.new.call(file: file, filename: 'inventory.xlsx')

    expect(import).to have_attributes(
      status: 'completed',
      total_rows: 1,
      success_rows: 1,
      failed_rows: 0,
      error_details: []
    )

    supplier = Pharma::Supplier.find_by!(code: 'SUP-IMPORT-001')
    warehouse = Pharma::SupplierWarehouse.find_by!(code: 'WH-IMPORT-001')
    drug = Pharma::DrugMaster.find_by!(approval_number: '国药准字HIMPORT001')
    offer = Pharma::SupplierOffer.find_by!(supplier: supplier, drug_master: drug, supplier_warehouse: warehouse)
    region = Pharma::SupplierOfferRegion.find_by!(supplier_offer: offer)
    stock = Pharma::DrugBatchStock.find_by!(supplier_offer: offer, batch_no: 'BATCH-IMPORT-001')

    expect(supplier).to have_attributes(status: 'pending', name: '华东医药供货有限公司')
    expect(warehouse).to have_attributes(name: '上海中心仓', district: '浦东新区')
    expect(drug).to have_attributes(
      common_name: '阿莫西林胶囊',
      trade_name: '阿莫西林',
      prescription_required: true,
      temperature_control: 'normal'
    )
    expect(offer).to have_attributes(status: 'approved', min_order_quantity: 10, max_order_quantity: 500)
    expect(offer.unit_price.to_s).to eq('8.5')
    expect(region).to have_attributes(province: '上海市', city: '上海市', district: '浦东新区', delivery_days: 1)
    expect(stock).to have_attributes(quantity_on_hand: 300, quantity_locked: 20)
    expect(stock.available_quantity).to eq(280)
  ensure
    file&.close!
  end

  it 'records row errors and continues importing valid rows' do
    file = build_inventory_file([
                                  valid_row('批准文号' => ''),
                                  valid_row('供应商编码' => 'SUP-IMPORT-002',
                                            '仓库编码' => 'WH-IMPORT-002',
                                            '批准文号' => '国药准字HIMPORT002',
                                            '批号' => 'BATCH-IMPORT-002')
                                ])

    import = described_class.new.call(file: file, filename: 'inventory.xlsx')

    expect(import).to have_attributes(status: 'completed_with_errors', total_rows: 2, success_rows: 1, failed_rows: 1)
    expect(import.error_details.first).to include('row' => 2)
    expect(import.error_details.first.fetch('message')).to include('批准文号')
    expect(Pharma::DrugMaster.exists?(approval_number: '国药准字HIMPORT002')).to be(true)
    expect(Pharma::DrugMaster.exists?(approval_number: '')).to be(false)
  ensure
    file&.close!
  end

  it 'marks the import failed when the workbook cannot be parsed' do
    file = Tempfile.new(['invalid-inventory', '.xlsx'])
    file.write('not a zip workbook')
    file.rewind

    import = described_class.new.call(file: file, filename: 'inventory.xlsx')

    expect(import).to have_attributes(status: 'failed', total_rows: 0, success_rows: 0, failed_rows: 0)
    expect(import.error_details.first.fetch('message')).to be_present
  ensure
    file&.close!
  end
end
