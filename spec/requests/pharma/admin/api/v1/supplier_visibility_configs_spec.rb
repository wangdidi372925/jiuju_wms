# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pharma admin supplier visibility config API', type: :request do
  def json_body
    JSON.parse(response.body)
  end

  let(:headers) { { 'X-Pharma-Admin-Token' => 'dev-admin-token' } }

  it 'requires an admin API token' do
    get '/pharma/admin/api/v1/supplier_visibility_config'

    expect(response).to have_http_status(:unauthorized)
    expect(json_body).to include('error' => 'unauthorized')
  end

  it 'returns the current supplier visibility mode' do
    Pharma::SupplierVisibilityConfig.current

    get '/pharma/admin/api/v1/supplier_visibility_config', headers: headers

    expect(response).to have_http_status(:ok)
    expect(json_body).to include(
      'data' => {
        'mode' => 'hidden',
        'active' => true
      }
    )
  end

  it 'updates the current supplier visibility mode' do
    patch '/pharma/admin/api/v1/supplier_visibility_config',
          params: { mode: 'visible' },
          headers: headers

    expect(response).to have_http_status(:ok)
    expect(json_body.dig('data', 'mode')).to eq('visible')
    expect(Pharma::SupplierVisibilityConfig.current.mode).to eq('visible')
  end

  it 'rejects invalid visibility mode' do
    patch '/pharma/admin/api/v1/supplier_visibility_config',
          params: { mode: 'unknown' },
          headers: headers

    expect(response).to have_http_status(:unprocessable_entity)
    expect(json_body).to include('error' => 'invalid_visibility_mode')
  end
end
