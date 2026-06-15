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
end
