# frozen_string_literal: true

require 'rails_helper'
require 'support/pharma_xlsx_fixture'

RSpec.describe 'Pharma operations catalog management', type: :request do
  include PharmaXlsxFixture

  def login_as_ops
    post '/pharma/ops/session', params: { token: 'dev-admin-token' }
  end

  def supplier_params(code: 'SUP-OPS-MGMT-001')
    {
      name: '华东医药供货有限公司',
      code: code,
      contact_name: '李经理',
      contact_phone: '13900019001',
      province: '上海市',
      city: '上海市',
      status: 'pending',
      priority: 10
    }
  end

  def license_params(license_no: 'SUP-OPS-MGMT-LICENSE-001')
    {
      license_type: 'drug_wholesale_license',
      license_no: license_no,
      status: 'approved',
      starts_on: Date.current.iso8601,
      expires_on: 1.year.from_now.to_date.iso8601
    }
  end

  def warehouse_params(code: 'WH-OPS-MGMT-001')
    {
      name: '上海中心仓',
      code: code,
      province: '上海市',
      city: '上海市',
      district: '浦东新区',
      address: '仓库路 19 号',
      cold_chain_enabled: '0',
      status: 'active'
    }
  end

  def drug_params(approval_number: '国药准字HOPSMGMT001')
    {
      common_name: '阿莫西林胶囊',
      trade_name: '阿莫西林',
      specification: '0.25g*24粒',
      dosage_form: '胶囊剂',
      manufacturer: '示例制药有限公司',
      approval_number: approval_number,
      package_unit: '盒',
      prescription_required: '1',
      storage_condition: '常温',
      temperature_control: 'normal',
      status: 'active'
    }
  end

  def approved_supplier_with_warehouse
    supplier = Pharma::Supplier.create!(supplier_params(code: 'SUP-OPS-MGMT-APPROVED').merge(status: 'approved'))
    Pharma::SupplierLicense.create!(license_params.merge(supplier: supplier))
    warehouse = Pharma::SupplierWarehouse.create!(warehouse_params(code: 'WH-OPS-MGMT-APPROVED').merge(supplier: supplier))

    [supplier, warehouse]
  end

  def inventory_headers
    [
      '供应商编码', '供应商名称', '供应商联系人', '供应商电话', '供应商省', '供应商市',
      '仓库编码', '仓库名称', '仓库省', '仓库市', '仓库区', '仓库地址',
      '通用名', '商品名', '规格', '剂型', '生产厂家', '批准文号', '包装单位',
      '是否处方', '储存条件', '温控', '单价', '起订量', '限购量',
      '报价状态', '报价开始', '报价结束', '可售省', '可售市', '可售区',
      '配送天数', '批号', '效期', '库存', '锁定库存'
    ]
  end

  def inventory_row
    [
      'SUP-OPS-IMPORT-001',
      '页面导入供应商',
      '张经理',
      '13900019999',
      '上海市',
      '上海市',
      'WH-OPS-IMPORT-001',
      '页面导入仓',
      '上海市',
      '上海市',
      '浦东新区',
      '导入仓库路 1 号',
      '布洛芬片',
      '布洛芬',
      '0.2g*24片',
      '片剂',
      '导入制药有限公司',
      '国药准字HOPSIMPORT001',
      '盒',
      '否',
      '常温',
      '常温',
      '6.8',
      '5',
      '200',
      'approved',
      '2026-06-01',
      '2026-12-31',
      '上海市',
      '上海市',
      '浦东新区',
      '1',
      'BATCH-OPS-IMPORT-001',
      '2028-06-01',
      '180',
      '0'
    ]
  end

  def upload_for(file)
    Rack::Test::UploadedFile.new(
      file.path,
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    )
  end

  it 'lets operations create and update suppliers with licenses and warehouses' do
    login_as_ops

    get '/pharma/ops/suppliers/new'
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('新增货盘方')

    post '/pharma/ops/suppliers', params: { supplier: supplier_params }
    supplier = Pharma::Supplier.find_by!(code: 'SUP-OPS-MGMT-001')

    expect(response).to redirect_to("/pharma/ops/suppliers/#{supplier.id}")
    expect(supplier).to have_attributes(name: '华东医药供货有限公司', status: 'pending')

    patch "/pharma/ops/suppliers/#{supplier.id}",
          params: { supplier: { status: 'approved', priority: 30 } }

    expect(response).to redirect_to("/pharma/ops/suppliers/#{supplier.id}")
    expect(supplier.reload).to have_attributes(status: 'approved', priority: 30)

    get "/pharma/ops/suppliers/#{supplier.id}/licenses/new"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('新增资质')

    post "/pharma/ops/suppliers/#{supplier.id}/licenses",
         params: { supplier_license: license_params }
    license = supplier.supplier_licenses.find_by!(license_no: 'SUP-OPS-MGMT-LICENSE-001')
    expect(response).to redirect_to("/pharma/ops/suppliers/#{supplier.id}")
    expect(license.status).to eq('approved')

    get "/pharma/ops/supplier_licenses/#{license.id}/edit"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('编辑资质')

    get "/pharma/ops/suppliers/#{supplier.id}/warehouses/new"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('新增仓库')

    post "/pharma/ops/suppliers/#{supplier.id}/warehouses",
         params: { supplier_warehouse: warehouse_params }
    warehouse = supplier.supplier_warehouses.find_by!(code: 'WH-OPS-MGMT-001')
    expect(response).to redirect_to("/pharma/ops/suppliers/#{supplier.id}")
    expect(warehouse.region_label).to eq('上海市 / 上海市 / 浦东新区')

    get "/pharma/ops/supplier_warehouses/#{warehouse.id}/edit"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('编辑仓库')

    get "/pharma/ops/suppliers/#{supplier.id}"
    expect(response.body).to include('SUP-OPS-MGMT-LICENSE-001')
    expect(response.body).to include('上海中心仓')
  end

  it 'lets operations create drugs, offers, sale regions, and batch stock' do
    supplier, warehouse = approved_supplier_with_warehouse
    login_as_ops

    get '/pharma/ops/drug_masters/new'
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('新增药品')

    post '/pharma/ops/drug_masters', params: { drug_master: drug_params }
    drug = Pharma::DrugMaster.find_by!(approval_number: '国药准字HOPSMGMT001')

    expect(response).to redirect_to("/pharma/ops/drug_masters/#{drug.id}/edit")
    expect(drug).to have_attributes(common_name: '阿莫西林胶囊', prescription_required: true)

    get "/pharma/ops/drug_masters/#{drug.id}/edit"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('编辑药品')

    patch "/pharma/ops/drug_masters/#{drug.id}",
          params: { drug_master: { storage_condition: '阴凉', temperature_control: 'cool' } }
    expect(response).to redirect_to("/pharma/ops/drug_masters/#{drug.id}/edit")
    expect(drug.reload).to have_attributes(storage_condition: '阴凉', temperature_control: 'cool')

    get '/pharma/ops/supplier_offers/new'
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('新增报价')

    post '/pharma/ops/supplier_offers',
         params: {
           supplier_offer: {
             supplier_id: supplier.id,
             drug_master_id: drug.id,
             supplier_warehouse_id: warehouse.id,
             unit_price: '8.5',
             min_order_quantity: 10,
             max_order_quantity: 500,
             status: 'approved',
             starts_at: 1.day.ago.iso8601,
             ends_at: 30.days.from_now.iso8601
           }
         }
    offer = Pharma::SupplierOffer.find_by!(supplier: supplier, drug_master: drug, supplier_warehouse: warehouse)

    expect(response).to redirect_to("/pharma/ops/supplier_offers/#{offer.id}")
    expect(offer.status).to eq('approved')

    get "/pharma/ops/supplier_offers/#{offer.id}/edit"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('编辑报价')

    get "/pharma/ops/supplier_offers/#{offer.id}/regions/new"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('新增可售区域')

    post "/pharma/ops/supplier_offers/#{offer.id}/regions",
         params: {
           supplier_offer_region: {
             province: '上海市',
             city: '上海市',
             district: '浦东新区',
             delivery_days: 1,
             status: 'active'
           }
         }
    expect(response).to redirect_to("/pharma/ops/supplier_offers/#{offer.id}")
    expect(offer.supplier_offer_regions.count).to eq(1)
    region = offer.supplier_offer_regions.last

    get "/pharma/ops/supplier_offer_regions/#{region.id}/edit"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('编辑可售区域')

    get "/pharma/ops/supplier_offers/#{offer.id}/batch_stocks/new"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('新增批号库存')

    post "/pharma/ops/supplier_offers/#{offer.id}/batch_stocks",
         params: {
           drug_batch_stock: {
             batch_no: 'BATCH-OPS-MGMT-001',
             expiry_date: 2.years.from_now.to_date.iso8601,
             quantity_on_hand: 300,
             quantity_locked: 0,
             status: 'active'
           }
         }
    stock = offer.drug_batch_stocks.find_by!(batch_no: 'BATCH-OPS-MGMT-001')
    expect(response).to redirect_to("/pharma/ops/supplier_offers/#{offer.id}")
    expect(stock.available_quantity).to eq(300)

    get "/pharma/ops/drug_batch_stocks/#{stock.id}/edit"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('编辑批号库存')

    get "/pharma/ops/supplier_offers/#{offer.id}"
    expect(response.body).to include('BATCH-OPS-MGMT-001')
    expect(response.body).to include('浦东新区')
  end

  it 'lets operations upload inventory xlsx and inspect import result' do
    login_as_ops
    file = build_xlsx([inventory_headers, inventory_row])

    get '/pharma/ops/inventory_imports/new'
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('上传货盘 Excel')

    post '/pharma/ops/inventory_imports',
         params: { inventory_import: { file: upload_for(file) } }
    import = Pharma::InventoryImport.order(:created_at).last

    expect(response).to redirect_to("/pharma/ops/inventory_imports/#{import.id}")
    expect(import).to have_attributes(status: 'completed', total_rows: 1, success_rows: 1, failed_rows: 0)

    get "/pharma/ops/inventory_imports/#{import.id}"
    expect(response.body).to include('completed')
    expect(response.body).to include('页面导入供应商')
  ensure
    file&.close!
  end
end
