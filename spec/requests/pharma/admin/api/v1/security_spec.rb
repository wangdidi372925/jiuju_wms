# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pharma admin API security', type: :request do
  def json_body
    JSON.parse(response.body)
  end

  def admin_client_headers(role:, name: "#{role} client")
    client, raw_token = Pharma::AdminApiClient.issue!(name: name, role: role)

    [{ 'X-Pharma-Admin-Token' => raw_token }, client]
  end

  def supplier_params(code: 'SUP-SECURITY-001')
    {
      name: '华东医药供货有限公司',
      code: code,
      contact_name: '李经理',
      contact_phone: '13900017001',
      province: '上海市',
      city: '上海市',
      status: 'pending',
      priority: 10
    }
  end

  it 'records an audit log for successful admin API requests' do
    headers, client = admin_client_headers(role: 'viewer', name: '只读审计客户端')

    expect do
      get '/pharma/admin/api/v1/supplier_visibility_config', headers: headers
    end.to change(Pharma::AdminAuditLog, :count).by(1)

    expect(response).to have_http_status(:ok)
    audit_log = Pharma::AdminAuditLog.last
    expect(audit_log).to have_attributes(
      admin_api_client: client,
      actor_name: '只读审计客户端',
      actor_role: 'viewer',
      request_method: 'GET',
      path: '/pharma/admin/api/v1/supplier_visibility_config',
      controller_path: 'pharma/admin/api/v1/supplier_visibility_configs',
      action_name: 'show',
      status: 200,
      error_code: nil
    )
  end

  it 'forbids write requests for viewer role and records the denial' do
    headers, client = admin_client_headers(role: 'viewer', name: '只读客户端')

    expect do
      post '/pharma/admin/api/v1/suppliers',
           params: supplier_params,
           headers: headers
    end.to change(Pharma::AdminAuditLog, :count).by(1)

    expect(response).to have_http_status(:forbidden)
    expect(json_body).to include('error' => 'forbidden', 'message' => '当前后台角色无权执行该操作')
    expect(Pharma::Supplier.exists?(code: 'SUP-SECURITY-001')).to be(false)

    audit_log = Pharma::AdminAuditLog.last
    expect(audit_log).to have_attributes(
      admin_api_client: client,
      actor_role: 'viewer',
      request_method: 'POST',
      action_name: 'create',
      status: 403,
      error_code: 'forbidden'
    )
    expect(audit_log.request_params).to include('code' => 'SUP-SECURITY-001')
  end

  it 'allows write requests for super admin role' do
    headers, client = admin_client_headers(role: 'super_admin', name: '超级管理员客户端')

    expect do
      post '/pharma/admin/api/v1/suppliers',
           params: supplier_params(code: 'SUP-SECURITY-002'),
           headers: headers
    end.to change(Pharma::AdminAuditLog, :count).by(1)

    expect(response).to have_http_status(:created)
    expect(json_body.dig('data', 'code')).to eq('SUP-SECURITY-002')

    audit_log = Pharma::AdminAuditLog.last
    expect(audit_log).to have_attributes(
      admin_api_client: client,
      actor_role: 'super_admin',
      request_method: 'POST',
      status: 201
    )
  end

  it 'records an audit log for invalid admin tokens' do
    expect do
      get '/pharma/admin/api/v1/supplier_visibility_config',
          headers: { 'X-Pharma-Admin-Token' => 'not-a-real-token' }
    end.to change(Pharma::AdminAuditLog, :count).by(1)

    expect(response).to have_http_status(:unauthorized)
    expect(json_body).to include('error' => 'unauthorized')

    audit_log = Pharma::AdminAuditLog.last
    expect(audit_log).to have_attributes(
      admin_api_client_id: nil,
      actor_name: nil,
      actor_role: nil,
      request_method: 'GET',
      status: 401,
      error_code: 'unauthorized'
    )
  end
end
