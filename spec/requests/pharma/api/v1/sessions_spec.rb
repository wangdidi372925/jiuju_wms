# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pharma pharmacy sessions API', type: :request do
  def json_body
    JSON.parse(response.body)
  end

  def approved_pharmacy(code: 'PH-SESSION-API-001')
    Pharma::Pharmacy.create!(
      name: '九州登录药店',
      code: code,
      contact_name: '王店长',
      contact_phone: '13800016001',
      province: '上海市',
      city: '上海市',
      district: '浦东新区',
      address: '张江路 16 号',
      status: 'approved'
    ).tap do |pharmacy|
      Pharma::PharmacyLicense.create!(
        pharmacy: pharmacy,
        license_type: 'drug_business_license',
        license_no: "#{code}-LICENSE",
        status: 'approved',
        starts_on: Date.current - 1.day,
        expires_on: Date.current + 1.year
      )
    end
  end

  def pharmacy_user_for(pharmacy:, email: 'buyer-session@example.com', password: 'Password123!')
    user = Spree::User.create!(
      email: email,
      password: password,
      password_confirmation: password
    )
    Pharma::PharmacyUser.create!(
      pharmacy: pharmacy,
      user: user,
      role: 'buyer',
      status: 'active'
    )
  end

  it 'creates a pharmacy API token for valid credentials' do
    pharmacy = approved_pharmacy
    pharmacy_user_for(pharmacy: pharmacy)

    post '/pharma/api/v1/session',
         params: {
           email: 'buyer-session@example.com',
           password: 'Password123!',
           pharmacy_code: pharmacy.code
         }

    expect(response).to have_http_status(:created)
    data = json_body.fetch('data')
    expect(data).to include(
      'token' => a_string_starting_with('pharm_'),
      'token_type' => 'Bearer',
      'pharmacy' => hash_including('code' => pharmacy.code, 'name' => '九州登录药店'),
      'user' => hash_including('email' => 'buyer-session@example.com', 'role' => 'buyer')
    )
    expect(Pharma::PharmacyApiToken.count).to eq(1)
    expect(Pharma::PharmacyApiToken.first.token_digest).not_to eq(data.fetch('token'))
  end

  it 'rejects invalid credentials' do
    pharmacy = approved_pharmacy
    pharmacy_user_for(pharmacy: pharmacy)

    post '/pharma/api/v1/session',
         params: {
           email: 'buyer-session@example.com',
           password: 'wrong-password',
           pharmacy_code: pharmacy.code
         }

    expect(response).to have_http_status(:unauthorized)
    expect(json_body).to include('error' => 'invalid_credentials', 'message' => '账号或密码错误')
  end

  it 'revokes the current token' do
    pharmacy = approved_pharmacy
    pharmacy_user = pharmacy_user_for(pharmacy: pharmacy)
    token_record, raw_token = Pharma::PharmacyApiToken.issue!(pharmacy_user: pharmacy_user)

    delete '/pharma/api/v1/session', headers: { 'Authorization' => "Bearer #{raw_token}" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch('data')).to include('revoked' => true)
    expect(token_record.reload.revoked_at).to be_present
  end
end
