# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pharma admin pharmacy review API', type: :request do
  def json_body
    JSON.parse(response.body)
  end

  def admin_headers
    { 'X-Pharma-Admin-Token' => 'dev-admin-token' }
  end

  def create_pharmacy(code: 'PH-REVIEW-001', status: 'pending')
    Pharma::Pharmacy.create!(
      name: '九州一号药店',
      code: code,
      contact_name: '王店长',
      contact_phone: '13800005001',
      province: '上海市',
      city: '上海市',
      district: '浦东新区',
      address: '张江路 5 号',
      status: status
    )
  end

  def create_license(pharmacy, status: 'pending')
    Pharma::PharmacyLicense.create!(
      pharmacy: pharmacy,
      license_type: 'drug_business_license',
      license_no: "LICENSE-#{pharmacy.code}",
      status: status,
      starts_on: Date.current - 1.day,
      expires_on: Date.current + 1.year
    )
  end

  it 'requires an admin API token' do
    get '/pharma/admin/api/v1/pharmacies'

    expect(response).to have_http_status(:unauthorized)
    expect(json_body).to include('error' => 'unauthorized')
  end

  it 'lists pharmacies filtered by status' do
    pending = create_pharmacy(code: 'PH-REVIEW-PENDING')
    create_pharmacy(code: 'PH-REVIEW-APPROVED', status: 'approved')

    get '/pharma/admin/api/v1/pharmacies',
        params: { status: 'pending' },
        headers: admin_headers

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch('data')).to contain_exactly(
      hash_including('id' => pending.id, 'code' => 'PH-REVIEW-PENDING', 'status' => 'pending')
    )
  end

  it 'shows pharmacy details with licenses' do
    pharmacy = create_pharmacy
    license = create_license(pharmacy)

    get "/pharma/admin/api/v1/pharmacies/#{pharmacy.id}", headers: admin_headers

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch('data')).to include(
      'id' => pharmacy.id,
      'code' => pharmacy.code,
      'licenses' => [
        hash_including('id' => license.id, 'status' => 'pending')
      ]
    )
  end

  it 'reviews pharmacy status' do
    pharmacy = create_pharmacy

    patch "/pharma/admin/api/v1/pharmacies/#{pharmacy.id}/review",
          params: { status: 'approved' },
          headers: admin_headers

    expect(response).to have_http_status(:ok)
    expect(json_body.dig('data', 'status')).to eq('approved')
    expect(pharmacy.reload).to be_approved
  end

  it 'rejects invalid pharmacy review status' do
    pharmacy = create_pharmacy

    patch "/pharma/admin/api/v1/pharmacies/#{pharmacy.id}/review",
          params: { status: 'pending' },
          headers: admin_headers

    expect(response).to have_http_status(422)
    expect(json_body).to include('error' => 'invalid_status')
  end

  it 'reviews pharmacy license status and enables purchasing when pharmacy is approved' do
    pharmacy = create_pharmacy(status: 'approved')
    license = create_license(pharmacy)

    patch "/pharma/admin/api/v1/pharmacy_licenses/#{license.id}/review",
          params: { status: 'approved' },
          headers: admin_headers

    expect(response).to have_http_status(:ok)
    expect(json_body.dig('data', 'status')).to eq('approved')
    expect(license.reload).to be_approved
    expect(pharmacy.reload).to be_purchasing_enabled
  end

  it 'rejects invalid pharmacy license review status' do
    pharmacy = create_pharmacy
    license = create_license(pharmacy)

    patch "/pharma/admin/api/v1/pharmacy_licenses/#{license.id}/review",
          params: { status: 'pending' },
          headers: admin_headers

    expect(response).to have_http_status(422)
    expect(json_body).to include('error' => 'invalid_status')
  end
end
