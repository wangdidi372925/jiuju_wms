# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pharma admin master data API', type: :request do
  def json_body
    JSON.parse(response.body)
  end

  def admin_headers
    { 'X-Pharma-Admin-Token' => 'dev-admin-token' }
  end

  def drug_params(approval_number: '国药准字HMASTER001')
    {
      common_name: '阿莫西林胶囊',
      trade_name: '阿莫西林胶囊',
      specification: '0.25g*24粒',
      dosage_form: '胶囊剂',
      manufacturer: '示例制药有限公司',
      approval_number: approval_number,
      package_unit: '盒',
      prescription_required: true,
      storage_condition: '常温',
      temperature_control: 'normal',
      status: 'active'
    }
  end

  def supplier_params(code: 'SUP-MASTER-001')
    {
      name: '华东医药供货有限公司',
      code: code,
      contact_name: '李经理',
      contact_phone: '13900006001',
      province: '上海市',
      city: '上海市',
      status: 'pending',
      priority: 10
    }
  end

  def supplier_license_params(license_no: 'SUP-MASTER-LICENSE-001')
    {
      license_type: 'drug_wholesale_license',
      license_no: license_no,
      status: 'pending',
      starts_on: Date.current.iso8601,
      expires_on: 1.year.from_now.to_date.iso8601
    }
  end

  def supplier_warehouse_params(code: 'WH-MASTER-001')
    {
      name: '上海中心仓',
      code: code,
      province: '上海市',
      city: '上海市',
      district: '浦东新区',
      address: '仓库路 6 号',
      cold_chain_enabled: false,
      status: 'active'
    }
  end

  describe 'drug masters' do
    it 'requires admin token' do
      get '/pharma/admin/api/v1/drug_masters'

      expect(response).to have_http_status(:unauthorized)
      expect(json_body).to include('error' => 'unauthorized')
    end

    it 'creates a drug master' do
      post '/pharma/admin/api/v1/drug_masters',
           params: drug_params,
           headers: admin_headers

      expect(response).to have_http_status(:created)
      expect(json_body.fetch('data')).to include(
        'common_name' => '阿莫西林胶囊',
        'approval_number' => '国药准字HMASTER001',
        'status' => 'active'
      )
    end

    it 'updates a drug master' do
      drug = Pharma::DrugMaster.create!(drug_params)

      patch "/pharma/admin/api/v1/drug_masters/#{drug.id}",
            params: { status: 'inactive', storage_condition: '阴凉' },
            headers: admin_headers

      expect(response).to have_http_status(:ok)
      expect(json_body.dig('data', 'status')).to eq('inactive')
      expect(json_body.dig('data', 'storage_condition')).to eq('阴凉')
    end

    it 'lists and shows drug masters' do
      drug = Pharma::DrugMaster.create!(drug_params)

      get '/pharma/admin/api/v1/drug_masters', headers: admin_headers
      expect(response).to have_http_status(:ok)
      expect(json_body.fetch('data')).to contain_exactly(hash_including('id' => drug.id))

      get "/pharma/admin/api/v1/drug_masters/#{drug.id}", headers: admin_headers
      expect(response).to have_http_status(:ok)
      expect(json_body.fetch('data')).to include('id' => drug.id, 'display_name' => drug.display_name)
    end

    it 'returns validation errors for invalid drug master data' do
      post '/pharma/admin/api/v1/drug_masters',
           params: drug_params.merge(common_name: ''),
           headers: admin_headers

      expect(response).to have_http_status(422)
      expect(json_body).to include('error' => 'validation_failed')
    end
  end

  describe 'suppliers, licenses, and warehouses' do
    it 'creates, updates, lists, and shows suppliers with nested data' do
      post '/pharma/admin/api/v1/suppliers',
           params: supplier_params,
           headers: admin_headers

      expect(response).to have_http_status(:created)
      supplier_id = json_body.dig('data', 'id')
      expect(json_body.fetch('data')).to include(
        'code' => 'SUP-MASTER-001',
        'status' => 'pending',
        'priority' => 10
      )

      patch "/pharma/admin/api/v1/suppliers/#{supplier_id}",
            params: { status: 'approved', priority: 20 },
            headers: admin_headers

      expect(response).to have_http_status(:ok)
      expect(json_body.dig('data', 'status')).to eq('approved')
      expect(json_body.dig('data', 'priority')).to eq(20)

      get '/pharma/admin/api/v1/suppliers', headers: admin_headers
      expect(response).to have_http_status(:ok)
      expect(json_body.fetch('data')).to include(hash_including('id' => supplier_id))

      get "/pharma/admin/api/v1/suppliers/#{supplier_id}", headers: admin_headers
      expect(response).to have_http_status(:ok)
      expect(json_body.fetch('data')).to include(
        'id' => supplier_id,
        'licenses' => [],
        'warehouses' => []
      )
    end

    it 'creates and updates supplier licenses' do
      supplier = Pharma::Supplier.create!(supplier_params)

      post "/pharma/admin/api/v1/suppliers/#{supplier.id}/licenses",
           params: supplier_license_params,
           headers: admin_headers

      expect(response).to have_http_status(:created)
      license_id = json_body.dig('data', 'id')
      expect(json_body.fetch('data')).to include(
        'supplier_id' => supplier.id,
        'license_no' => 'SUP-MASTER-LICENSE-001',
        'status' => 'pending'
      )

      patch "/pharma/admin/api/v1/supplier_licenses/#{license_id}",
            params: { status: 'approved' },
            headers: admin_headers

      expect(response).to have_http_status(:ok)
      expect(json_body.dig('data', 'status')).to eq('approved')
    end

    it 'creates and updates supplier warehouses' do
      supplier = Pharma::Supplier.create!(supplier_params)

      post "/pharma/admin/api/v1/suppliers/#{supplier.id}/warehouses",
           params: supplier_warehouse_params,
           headers: admin_headers

      expect(response).to have_http_status(:created)
      warehouse_id = json_body.dig('data', 'id')
      expect(json_body.fetch('data')).to include(
        'supplier_id' => supplier.id,
        'code' => 'WH-MASTER-001',
        'region_label' => '上海市 / 上海市 / 浦东新区'
      )

      patch "/pharma/admin/api/v1/supplier_warehouses/#{warehouse_id}",
            params: { status: 'suspended', cold_chain_enabled: true },
            headers: admin_headers

      expect(response).to have_http_status(:ok)
      expect(json_body.dig('data', 'status')).to eq('suspended')
      expect(json_body.dig('data', 'cold_chain_enabled')).to be(true)
    end
  end
end
