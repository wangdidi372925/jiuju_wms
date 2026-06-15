# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pharma pharmacy onboarding API', type: :request do
  def json_body
    JSON.parse(response.body)
  end

  def pharmacy_params(code: 'PH-ONBOARD-001')
    {
      name: '九州一号药店',
      code: code,
      contact_name: '王店长',
      contact_phone: '13800004001',
      province: '上海市',
      city: '上海市',
      district: '浦东新区',
      address: '张江路 4 号'
    }
  end

  def license_params
    {
      license_type: 'drug_business_license',
      license_no: 'PH-ONBOARD-LICENSE-001',
      starts_on: Date.current.iso8601,
      expires_on: 1.year.from_now.to_date.iso8601
    }
  end

  it 'creates a pending pharmacy' do
    post '/pharma/api/v1/pharmacies', params: pharmacy_params

    expect(response).to have_http_status(:created)
    expect(json_body.fetch('data')).to include(
      'code' => 'PH-ONBOARD-001',
      'name' => '九州一号药店',
      'status' => 'pending',
      'purchasing_enabled' => false
    )
    expect(Pharma::Pharmacy.find_by!(code: 'PH-ONBOARD-001')).to be_pending
  end

  it 'returns validation errors when pharmacy code already exists' do
    Pharma::Pharmacy.create!(pharmacy_params.merge(status: 'pending'))

    post '/pharma/api/v1/pharmacies', params: pharmacy_params

    expect(response).to have_http_status(422)
    expect(json_body).to include('error' => 'validation_failed')
  end

  it 'creates a pending pharmacy license' do
    pharmacy = Pharma::Pharmacy.create!(pharmacy_params.merge(status: 'pending'))

    post "/pharma/api/v1/pharmacies/#{pharmacy.code}/licenses", params: license_params

    expect(response).to have_http_status(:created)
    expect(json_body.fetch('data')).to include(
      'license_type' => 'drug_business_license',
      'license_no' => 'PH-ONBOARD-LICENSE-001',
      'status' => 'pending'
    )
    expect(pharmacy.reload.pharmacy_licenses.first).to be_pending
  end

  it 'returns not found when submitting a license for a missing pharmacy' do
    post '/pharma/api/v1/pharmacies/PH-MISSING/licenses', params: license_params

    expect(response).to have_http_status(:not_found)
    expect(json_body).to include('error' => 'not_found')
  end
end
