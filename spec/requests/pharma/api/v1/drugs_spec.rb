# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pharma drug procurement API', type: :request do
  def json_body
    JSON.parse(response.body)
  end

  def create_drug(common_name:, approval_number:, status: 'active')
    Pharma::DrugMaster.create!(
      common_name: common_name,
      specification: '0.25g*24粒',
      dosage_form: '胶囊剂',
      manufacturer: '示例制药有限公司',
      approval_number: approval_number,
      package_unit: '盒',
      storage_condition: '常温',
      temperature_control: 'normal',
      status: status
    )
  end

  def create_pharmacy
    Pharma::Pharmacy.create!(
      name: '九州一号药店',
      code: 'PH-API-001',
      contact_name: '王店长',
      contact_phone: '13800001001',
      province: '上海市',
      city: '上海市',
      district: '浦东新区',
      address: '张江路 1 号',
      status: 'approved'
    ).tap do |pharmacy|
      Pharma::PharmacyLicense.create!(
        pharmacy: pharmacy,
        license_type: 'drug_business_license',
        license_no: 'PH-API-LICENSE-001',
        status: 'approved',
        starts_on: Date.current - 1.day,
        expires_on: Date.current + 1.year
      )
    end
  end

  def create_offer_for(drug)
    supplier = Pharma::Supplier.create!(
      name: '华东医药供货有限公司',
      code: 'SUP-API-001',
      contact_name: '李经理',
      contact_phone: '13900001001',
      province: '上海市',
      city: '上海市',
      status: 'approved',
      priority: 10
    )
    Pharma::SupplierLicense.create!(
      supplier: supplier,
      license_type: 'drug_wholesale_license',
      license_no: 'SUP-API-LICENSE-001',
      status: 'approved',
      starts_on: Date.current - 1.day,
      expires_on: Date.current + 1.year
    )
    warehouse = Pharma::SupplierWarehouse.create!(
      supplier: supplier,
      name: '上海中心仓',
      code: 'WH-API-001',
      province: '上海市',
      city: '上海市',
      district: '浦东新区',
      address: '仓库路 1 号',
      status: 'active'
    )
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
      batch_no: 'BATCH-API-001',
      expiry_date: Date.current + 2.years,
      quantity_on_hand: 100,
      quantity_locked: 0,
      status: 'active'
    )

    offer
  end

  it 'searches active drug masters by query' do
    drug = create_drug(common_name: '阿莫西林胶囊', approval_number: '国药准字HAPI0001')
    create_drug(common_name: '布洛芬片', approval_number: '国药准字HAPI0002')
    create_drug(common_name: '阿莫西林干混悬剂', approval_number: '国药准字HAPI0003', status: 'inactive')

    get '/pharma/api/v1/drugs', params: { query: '阿莫西林' }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch('data')).to contain_exactly(
      hash_including(
        'id' => drug.id,
        'common_name' => '阿莫西林胶囊',
        'approval_number' => '国药准字HAPI0001'
      )
    )
  end

  it 'returns purchasable offers with hidden supplier display by default' do
    pharmacy = create_pharmacy
    drug = create_drug(common_name: '阿莫西林胶囊', approval_number: '国药准字HAPI0004')
    offer = create_offer_for(drug)

    get "/pharma/api/v1/drugs/#{drug.id}/offers",
        params: {
          pharmacy_code: pharmacy.code,
          quantity: 10,
          province: '上海市',
          city: '上海市'
        }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch('data')).to contain_exactly(
      hash_including(
        'id' => offer.id,
        'unit_price' => '8.5',
        'available_quantity' => 100,
        'delivery_days' => 1,
        'supplier_display' => {
          'mode' => 'hidden',
          'supplier_visible' => false,
          'supplier_name' => nil,
          'label' => '平台优选'
        }
      )
    )
  end

  it 'returns not found when pharmacy code does not exist' do
    drug = create_drug(common_name: '阿莫西林胶囊', approval_number: '国药准字HAPI0005')

    get "/pharma/api/v1/drugs/#{drug.id}/offers",
        params: {
          pharmacy_code: 'PH-MISSING',
          quantity: 10,
          province: '上海市'
        }

    expect(response).to have_http_status(:not_found)
    expect(json_body).to include('error' => 'not_found')
  end
end
